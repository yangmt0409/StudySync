//
//  Item.swift
//  StudySync
//
//  Created by James Yang on 2026/3/17.
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
