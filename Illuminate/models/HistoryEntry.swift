//
//  HistoryEntry.swift
//  Illuminate
//
//  Created by Illuminate on 8/10/26.
//

import Foundation
import SwiftData

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID

    var urlString: String
    var title: String
    var faviconURLString: String?
    var firstVisited: Date
    var lastVisited: Date
    var visitCount: Int
    var url: URL? { URL(string: urlString) }
    var faviconURL: URL? {
        guard let s = faviconURLString else { return nil }
        return URL(string: s)
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        return url?.host ?? urlString
    }

    init(
        id: UUID = UUID(),
        urlString: String,
        title: String,
        faviconURLString: String? = nil,
        firstVisited: Date = Date(),
        lastVisited: Date = Date(),
        visitCount: Int = 1
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.faviconURLString = faviconURLString
        self.firstVisited = firstVisited
        self.lastVisited = lastVisited
        self.visitCount = visitCount
    }
}
