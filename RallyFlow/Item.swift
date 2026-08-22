//
//  Item.swift
//  RallyFlow
//
//  Created by Arez on 22/08/26.
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
