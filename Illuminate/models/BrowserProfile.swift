//
//  BrowserProfile.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/22/26.
//

import Foundation

struct BrowserProfile: Identifiable, Codable, Hashable {
    struct DownloadPreferences: Codable, Hashable {
        var safeDownloadsOnly: Bool
        var revealInFinderWhenFinished: Bool

        init(
            safeDownloadsOnly: Bool = true,
            revealInFinderWhenFinished: Bool = false
        ) {
            self.safeDownloadsOnly = safeDownloadsOnly
            self.revealInFinderWhenFinished = revealInFinderWhenFinished
        }
    }

    let id: UUID
    var name: String
    var iconName: String
    var createdAt: Date
    var downloadPreferences: DownloadPreferences

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "person.crop.circle",
        createdAt: Date = Date(),
        downloadPreferences: DownloadPreferences = .init()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
        self.downloadPreferences = downloadPreferences
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "person.crop.circle"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.downloadPreferences = try container.decodeIfPresent(DownloadPreferences.self, forKey: .downloadPreferences) ?? .init()
    }
}
