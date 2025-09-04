//
//  Item.swift
//  MarketsWidgetKit
//
//  Created by Edwin Bosire on 04/09/2025.
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
