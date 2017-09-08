//
//  SSHTunnelDelegate
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/25/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation

/**
 An SSHTunnelDelegate-compatible object interacts with an SSHTunnel object to handle the process of authenticating and
 maintaining a connection with an SSH server.
 */
public protocol SSHTunnelDelegate: class {
    /**
     When negotiating the SSH connection, the server returns a fingerprint hash based on the hostname used to connect
     and the given username. The delegate should then check an existing list of hash to determine whether the host's
     fingerprint is already in the list (it won't be if it's a new connection), and if so, whether the given hash
     matches the one already in the list. The delegate should return `true` if the fingerprint matches, and `false`
     if it doesn't.
     
     
     - parameter sshTunnel: The SSHTunnelProtocol-compliant caller.
     - parameter fingerprintData: The fingerprint hash returned by the SSH server.
     - returns: Bool declaring whether fingerprint is safe and authentication should continue.
     */
    
    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, returnedFingerprint fingerprintData: String)

    /**
     During authentication, the SSHTunnel object will notify the delegate that authentication data is needed, and
     provide a list of compatible `AuthenticationMethods`. If necessary, the delegate can then prompt the user before
     calling `sendAuthenticationData` to send the user's credentials.
     
     
     - parameter sshTunnel: The SSHTunnelProtocol-compilant caller.
     - parameter methods: The AuthenticationMethods reported by the server as being supported.
     */
    
    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, requestsAuthentication methods: [AuthenticationMethods])
    
    /**
     After a connection is successfully established, the delegate will be notified and given a port on localhost
     where communication can take place.
     
     
     - parameter sshTunnel: The SSHTunnelProtocol-compilant caller.
     - parameter port: The port on localhost where the app can connect.
     */
    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, beganListeningOn port: Int)
    
    /**
     If the connection experiences a fatal error, the delegate will be notified.
     
     
     - parameter sshTunnel: The SSHTunnelProtocol-compliant caller.
     - parameter error: The cause of the disconnect
     */
    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, didFailWithError error: Error)
}
