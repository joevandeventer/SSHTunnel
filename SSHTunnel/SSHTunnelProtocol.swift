//
//  SSHTunnelProtocol.swift
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/25/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation

public typealias SSHTunnelConnectCallback = (_ success: Bool, _ error: Error) -> ()

/// Protocol for an SSHTunnel-compatible object.
public protocol SSHTunnelProtocol {
    /// Tell SSHTunnel object to begin attempting to connect. Requires host, port, and delegate to be set.
    func connect()
    
    /**
     
     */
    func fingerprintIsAcceptable(_ acceptable: Bool)
    
    /**
     Attempt to send a user's authentication data to SSH server. Requires a prior call to `requestsAuthentication`.
     
     - Parameters:
         - An `AuthenticationData` enum supported by the SSH server.
     */
    
    // FIXME: Invalid `AuthenticationData` will currently cause a full disconnect from the server.
    
    func sendAuthenticationData(_ authenticationData: AuthenticationData)

    /**
     Disconnect all SSH channels and tear down the server connection. If called with an error parameter,
     `didFailWithError` will be sent to the delegate. Can also be called intentionally without an error
     object, in which case, the delegate isn't notified.
     
     - Parameters:
         - An optional `Error` object explaining why the disconnect occurred.
     */
    func disconnect(withError error: Error?)
}
