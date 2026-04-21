//
//  Item.swift
//  DiveLog Pro
//
//  Created by Dominik Weckherlin on 21.04.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
