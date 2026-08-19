//
//  Item.swift
//  DemonicSlots
//
//  Created by David Martens on 19.08.26.
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
