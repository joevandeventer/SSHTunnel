//
//  SSHTunnelProtocol.swift
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/25/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation

public typealias SSHTunnelConnectCallback = (_ success: Bool, _ error: Error) -> ()

public protocol SSHTunnelProtocol {
    func connect()
    func sendAuthenticationData(_ authenticationData: AuthenticationData)
    func disconnect()
}
