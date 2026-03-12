//
//  TabGroup.swift
//  Illuminate
//

import Foundation
import SwiftUI

struct TabGroup: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var color: String // Hex string
    var isExpanded: Bool

    init(id: UUID = UUID(), name: String, color: String, isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.color = color
        self.isExpanded = isExpanded
    }
}
