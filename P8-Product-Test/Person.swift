//
// Person.swift
// P8-Product-Test
//

import Foundation
import SwiftData

// Represents a single mole marker placed on the 3D mannequin
struct MoleMarker: Identifiable, Codable {
    let id: UUID
    let worldX: Float   // 3D world position on the mannequin surface
    let worldY: Float
    let worldZ: Float
    let timestamp: Date
    var notes: String

    init(worldX: Float, worldY: Float, worldZ: Float, timestamp: Date = Date(), notes: String = "") {
        self.id = UUID()
        self.worldX = worldX
        self.worldY = worldY
        self.worldZ = worldZ
        self.timestamp = timestamp
        self.notes = notes
    }
}

@Model
final class Person {
    var name: String
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var moles: [MoleMarker] = []
    @Relationship(deleteRule: .cascade, inverse: \HistoryItem.person) var historyItems: [HistoryItem] = []
    
    init(name: String, timestamp: Date = Date()) {
        self.name = name
        self.timestamp = timestamp
        self.moles = []
    }
}