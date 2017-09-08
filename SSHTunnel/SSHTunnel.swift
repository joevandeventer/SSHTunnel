//
//  SSHTunnel.swift
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/25/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation
import CoreFoundation

internal typealias Socket = Int32
internal typealias SSH2Session = OpaquePointer
internal typealias SSH2Channel = OpaquePointer

public enum SSHTunnelError: Error {
    case HostnameLookupError
    case SSH2ConnectionError
    case SSH2FingerprintError
    case SSH2AuthenticationError
    case SSH2ListenError
    case SSH2RemoteDisconnectError
}

public class SSHTunnel: SSHTunnelProtocol {
    let hostname: String
    let remotePort: Int
    let username: String
    private(set) var sshPort: Int
    private(set) weak var delegate: SSHTunnelDelegate?
    private(set) var isConnected: Bool
    private(set) var localPort: Int?
    private(set) var remoteIP: String?

    private var sshHostSocket: Socket?
    private var listeningSocket: Socket?
    
    private var sshSession: SSH2Session?
    
    private var queue = DispatchQueue(label: "SSHTunnel", attributes: .concurrent)
    private var connections = OperationQueue()
    
    required public init(toHostname hostname: String, port: Int, username: String, delegate: SSHTunnelDelegate, sshPort: Int = 22) {
        self.hostname = hostname
        self.remotePort = port
        self.username = username
        self.delegate = delegate
        self.isConnected = false
        self.sshPort = sshPort
    }
    
    public func connect() {
        let connectOperations = OperationQueue()
        connectOperations.isSuspended = true
        
        self.queue.async {
            do {
                try self.bindSocketToServer()
                try self.openSSHConnection()
            } catch {
                self.disconnect(withError: error)
            }
        }
    }
    
    private func bindSocketToServer() throws {
        // First, create a pointer to an empty addrinfo struct to hold the results linked list
        var servInfoPtr:UnsafeMutablePointer<addrinfo>? = UnsafeMutablePointer<addrinfo>.allocate(capacity: 1)
        
        // Don't forget to release at the end!
        // Using freeaddrinfo guarantees the entire linked list is released, not just the first pointer.
        defer {
            freeaddrinfo(servInfoPtr)
        }
        
        // Now create a "hints" struct to tell getaddrinfo what kind of results we want.
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        
        // Now, perform the hostname lookup
        if getaddrinfo(self.hostname, String(self.sshPort), &hints, &servInfoPtr) != 0 {
            throw SSHTunnelError.HostnameLookupError
        }
        
        guard let firstAddr = servInfoPtr else {
            throw SSHTunnelError.HostnameLookupError
        }
        
        // Now, iterate through the linked list to find valid addresses
        for addr in sequence(first: firstAddr, next: {$0.pointee.ai_next}) {
            let address = addr.pointee
            let sock:Socket = socket(address.ai_family, address.ai_socktype, address.ai_protocol)
            if sock < 0 {
                continue
            }
            
            if Darwin.connect(sock, address.ai_addr, address.ai_addrlen) != 0 {
                continue
            }
            
            self.sshHostSocket = sock
            return
        }
        
        throw SSHTunnelError.HostnameLookupError
    }
    
    private func openSSHConnection() throws {
        self.sshSession = libssh2_session_init_ex(nil, nil, nil, nil)
        guard
            let session = self.sshSession,
            let socket = self.sshHostSocket,
            let delegate = self.delegate
        else {
            throw SSHTunnelError.SSH2ConnectionError
        }
        
        if libssh2_session_handshake(session, socket) != 0 {
            throw SSHTunnelError.SSH2ConnectionError
        }
        
        guard let fingerprint = libssh2_hostkey_hash(session, LIBSSH2_HOSTKEY_HASH_SHA1) else {
            throw SSHTunnelError.SSH2ConnectionError
        }
        
        delegate.sshTunnel(self, returnedFingerprint: String(cString: fingerprint))
    }
    
    public func fingerprintIsAcceptable(_ acceptable: Bool) {
        if !acceptable {
            self.disconnect(withError: SSHTunnelError.SSH2FingerprintError)
            return
        }
        
        self.queue.async {
            do {
                try self.beginSSHAuthentication()
            } catch {
                self.disconnect(withError: error)
                return
            }
        }
    }
    
    private func beginSSHAuthentication() throws {
        guard
            let session = self.sshSession,
            let delegate = self.delegate
        else {
            self.disconnect(withError: SSHTunnelError.SSH2ConnectionError)
            return
        }
        
        guard let userAuthList = libssh2_userauth_list(session, self.username, UInt32(self.username.characters.count)) else {
            self.disconnect(withError: SSHTunnelError.SSH2AuthenticationError)
            return
        }
        
        let authStrings = String(cString: userAuthList).components(separatedBy: " ")
        
        var authMethods = Array<AuthenticationMethods>()
        for authString in authStrings {
            if let method = AuthenticationMethods(rawValue: authString) {
                authMethods.append(method)
            }
        }
        
        DispatchQueue.main.async {
            delegate.sshTunnel(self, requestsAuthentication: authMethods)
        }
    }
    
    public func sendAuthenticationData(_ authenticationData: AuthenticationData) {
        guard let session = self.sshSession else {
            self.disconnect(withError: SSHTunnelError.SSH2ConnectionError)
            return
        }
        self.queue.async {
            let result: Int32
            switch authenticationData {
            case let .password(password):
                result = libssh2_userauth_password_ex(session,
                                                          self.username,
                                                          UInt32(self.username.characters.count),
                                                          password,
                                                          UInt32(password.characters.count),
                                                          nil)
            case let .certificate(publicKeyPath, privateKeyPath):
                result = libssh2_userauth_publickey_fromfile_ex(session,
                                                                    self.username,
                                                                    UInt32(self.username.characters.count),
                                                                    publicKeyPath.path,
                                                                    privateKeyPath.path,
                                                                    nil)
            }
            
            if result != 0 {
                self.disconnect(withError: SSHTunnelError.SSH2ConnectionError)
                return
            }
            
            self.startListeningLocally()
        }
    }
    
    private func startListeningLocally() {
        guard let session = self.sshSession else {
            self.disconnect(withError: SSHTunnelError.SSH2ConnectionError)
            return
        }
        // Since this is just a local connection, hardcoding to IPv4 is fine.
        // We're going to bind to 127.0.0.1 because we only want this machine to use the connection.
        // But we're still setting the port to 0 and taking whatever the system gives us.
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0.bigEndian)
        inet_aton("127.0.0.1", &address.sin_addr)
        let sockfd:Socket = socket(PF_INET, SOCK_STREAM, 0)
        if sockfd < 0 {
            self.disconnect(withError: SSHTunnelError.SSH2ListenError)
            return
        }
        
        // Bind the socket!
        let _ = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sockfd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        // Start listening on said socket
        var intPtr = 1
        setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &intPtr, socklen_t(MemoryLayout<Int32>.size))
        Darwin.listen(sockfd, 5)
        
        
        // Now that we're listening, find out the port number assigned to us by the system.
        var sad = sockaddr.zeroed()
        var sadPtrLen = socklen_t(MemoryLayout<sockaddr>.size)
        getsockname(sockfd, &sad, &sadPtrLen)
        let _ = withUnsafePointer(to: &sad) {
            $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                let port = Int($0.pointee.sin_port.bigEndian)
                self.localPort = port
                self.isConnected = true
                DispatchQueue.main.async {
                    self.delegate?.sshTunnel(self, beganListeningOn: port)
                }
            }
        }
        
        // This loop will just run till we die, blocking on accept
        while true {
            var connectedAddrInfo = sockaddr.zeroed()
            var addrInfoSize:socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
            let requestDescriptor = accept(sockfd, &connectedAddrInfo, &addrInfoSize)
            
            if requestDescriptor == -1 {
                self.disconnect(withError: SSHTunnelError.SSH2ListenError)
                break
            }
            
            let newConnection = SSHTunnelConnection(session: session, socket: requestDescriptor, remotePort: self.remotePort)
            self.connections.addOperation(newConnection)
        }
    }
    
    public func disconnect(withError error: Error? = nil) {
        for oper in self.connections.operations {
            oper.cancel()
        }
        
        if let sshSession = self.sshSession {
            libssh2_session_disconnect_ex(sshSession, SSH_DISCONNECT_BY_APPLICATION, "", nil)
            libssh2_session_free(sshSession)
        }
        
        if let hostSocket = self.sshHostSocket {
            close(hostSocket)
        }
        
        if let listenSocket = self.sshHostSocket {
            close(listenSocket)
        }
        
        libssh2_exit()
        
        self.isConnected = false
        
        if let myError = error, let delegate = self.delegate {
            DispatchQueue.main.async {
                delegate.sshTunnel(self, didFailWithError: myError)
            }
        }
    }
    
    deinit {
        self.disconnect()
    }
}
