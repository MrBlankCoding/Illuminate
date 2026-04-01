//
//  BrowserProfile.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/22/26.
//

import Foundation

struct BrowserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, iconName: String = "person.crop.circle", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "person.crop.circle"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
