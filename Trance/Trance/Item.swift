//
//  Item.swift
//  Trance
//
//  Created by Chresten Soelberg on 01/09/2026.
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
