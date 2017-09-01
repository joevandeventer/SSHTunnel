//
//  SSHTunnelDelegate
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/25/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation

public protocol SSHTunnelDelegate: class {
    // Determine if the host is who it says it is. Application is responsible for maintaining a database of
    // previously seen hostkeys - SOP is to approve if the fingerprints match, prompt the user to save if the
    // host has never been seen before, and present a warning STRONGLY urging the user not to connect if the
    // two fingerprints don't match.
    //
    // Returning false will stop the connection process.
    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, returnedFingerprint fingerprintData: String) -> Bool

    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, requestsAuthentication methods: [AuthenticationMethods])
    
    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, beganListeningOn port: Int)
    
    func sshTunnel(_ sshTunnel: SSHTunnelProtocol, didFailWithError: Error)
}
