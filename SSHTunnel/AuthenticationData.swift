//
//  AuthenticationData.swift
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/25/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation

public enum AuthenticationData {
    case password(password: String)
    case certificate(publicKeyPath: URL, privateKeyPath: URL)
}
