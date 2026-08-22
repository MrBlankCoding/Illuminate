//
//  Bookmark.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation
import SwiftData

@Model
final class Bookmark: Identifiable {
    @Attribute(.unique) var id: UUID
    var profileID: UUID
    var title: String
    var url: String

    init(id: UUID = UUID(), profileID: UUID, title: String, url: String) {
        self.id = id
        self.profileID = profileID
        self.title = title
        self.url = url
    }
}

// Could add date created to sort by that???
// who knows
// YOURE SUCH A BACKSTABBERRRR!!!!
