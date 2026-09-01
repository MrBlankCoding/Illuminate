//
//  Easel.swift
//  Illuminate 
//
//  Created by MrBlankCoding on 8/30/26.
//

import Foundation

struct Easel: Identifiable, Codable, Equatable, Sendable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Untitled Easel",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    var url: URL {
        //illuminate://easel/<uuid>
        URL(string: "illuminate://easel/\(id.uuidString)")!
    }

    static func id(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == "illuminate",
              url.host?.lowercased() == "easel" else { return nil }
        // path is "/<uuid>"
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return UUID(uuidString: path)
    }
}

struct EaselDocument: Codable, Sendable {
    var canvasJSON: String?
    var version: Int = 1
}
