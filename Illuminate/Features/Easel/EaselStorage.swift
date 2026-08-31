//
//  EaselStorage.swift
//  Illuminate 
//
//  Created by MrBlankCoding on 8/30/26.
//

import Foundation
import AppKit

enum EaselStorage {

    static func easelsDirectory(profileID: UUID?) -> URL {
        let base: URL
        if let id = profileID {
            base = FileManager.default.illuminateProfileDirectory(profileID: id)
        } else {
            base = FileManager.default.illuminateAppSupportDirectory()
        }
        let dir = base.appendingPathComponent("Easels", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func indexURL(profileID: UUID?) -> URL {
        easelsDirectory(profileID: profileID).appendingPathComponent("index.json")
    }

    static func documentURL(for id: UUID, profileID: UUID?) -> URL {
        easelsDirectory(profileID: profileID).appendingPathComponent("\(id.uuidString).json")
    }

    static func loadIndex(profileID: UUID?) -> [Easel] {
        let url = indexURL(profileID: profileID)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Easel].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveIndex(_ easels: [Easel], profileID: UUID?) {
        let url = indexURL(profileID: profileID)
        guard let data = try? JSONEncoder().encode(easels) else { return }
        // atomic
        try? data.write(to: url, options: [.atomic])
    }

    static func loadDocument(id: UUID, profileID: UUID?) -> EaselDocument? {
        let url = documentURL(for: id, profileID: profileID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(EaselDocument.self, from: data)
    }

    static func saveDocument(_ doc: EaselDocument, id: UUID, profileID: UUID?) {
        let url = documentURL(for: id, profileID: profileID)
        guard let data = try? JSONEncoder().encode(doc) else { return }
        // atomic write via temporary + replace
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".\(id.uuidString).tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            // replace
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmp, to: url)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            AppLog.error("EaselStorage saveDocument failed", error: error)
        }
    }

    static func deleteDocument(id: UUID, profileID: UUID?) {
        let url = documentURL(for: id, profileID: profileID)
        try? FileManager.default.removeItem(at: url)
        // also delete preview
        let pURL = previewURL(for: id, profileID: profileID)
        try? FileManager.default.removeItem(at: pURL)
    }

    // MARK: - Preview (PNG thumbnail)

    static func previewURL(for id: UUID, profileID: UUID?) -> URL {
        easelsDirectory(profileID: profileID).appendingPathComponent("\(id.uuidString)_preview.png")
    }

    static func savePreview(dataURL: String, id: UUID, profileID: UUID?) {
        // dataURL is like "data:image/png;base64,iVBOR..."
        guard let comma = dataURL.firstIndex(of: ",") else { return }
        let b64 = String(dataURL[dataURL.index(after: comma)...])
        guard let data = Data(base64Encoded: b64) else { return }
        let url = previewURL(for: id, profileID: profileID)
        try? data.write(to: url, options: [.atomic])
    }

    static func loadPreviewImage(id: UUID, profileID: UUID?) -> NSImage? {
        let url = previewURL(for: id, profileID: profileID)
        guard let data = try? Data(contentsOf: url), let img = NSImage(data: data) else { return nil }
        return img
    }
}
