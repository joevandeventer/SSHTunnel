//
//  Sockaddr+Extensions.swift
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/29/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation

extension sockaddr {
    static func zeroed() -> sockaddr {
        return sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }
}

extension sockaddr_in {
}
