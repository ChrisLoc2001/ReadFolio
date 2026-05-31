//
//  Item.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
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
