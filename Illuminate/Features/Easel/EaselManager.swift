//
//  EaselManager.swift
//  Illuminate 
//
//  Created by MrBlankCoding on 8/30/26.
//

import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class EaselManager {
    var easels: [Easel] = []

    @ObservationIgnored private let profileID: UUID?
    @ObservationIgnored private let isPersistenceEnabled: Bool

    init(profileID: UUID? = nil, isPersistenceEnabled: Bool = true) {
        self.profileID = profileID
        self.isPersistenceEnabled = isPersistenceEnabled
        self.easels = EaselStorage.loadIndex(profileID: profileID)
        // sort by modified desc
        self.easels.sort { $0.modifiedAt > $1.modifiedAt }
    }

    @discardableResult
    func createEasel(title: String = "Untitled Easel") -> Easel {
        let easel = Easel(title: title)
        easels.insert(easel, at: 0)
        persistIndex()
        // create blank document
        let doc = EaselDocument(canvasJSON: nil)
        EaselStorage.saveDocument(doc, id: easel.id, profileID: profileID)
        return easel
    }

    func easel(for id: UUID) -> Easel? {
        easels.first { $0.id == id }
    }

    func easel(for url: URL) -> Easel? {
        guard let id = Easel.id(from: url) else { return nil }
        return easel(for: id)
    }

    func renameEasel(id: UUID, to newTitle: String) {
        guard let idx = easels.firstIndex(where: { $0.id == id }) else { return }
        easels[idx].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled Easel"
        easels[idx].modifiedAt = Date()
        persistIndex()
    }

    func deleteEasel(id: UUID) {
        easels.removeAll { $0.id == id }
        persistIndex()
        EaselStorage.deleteDocument(id: id, profileID: profileID)
    }

    func touchEasel(id: UUID) {
        guard let idx = easels.firstIndex(where: { $0.id == id }) else { return }
        easels[idx].modifiedAt = Date()
        // move to front
        let e = easels.remove(at: idx)
        easels.insert(e, at: 0)
        persistIndex()
    }

    func updateModifiedDateAndSort(id: UUID) {
        touchEasel(id: id)
    }

    func loadDocument(id: UUID) -> EaselDocument? {
        EaselStorage.loadDocument(id: id, profileID: profileID)
    }

    func saveDocument(jsonString: String?, id: UUID) {
        var doc = EaselStorage.loadDocument(id: id, profileID: profileID) ?? EaselDocument()
        doc.canvasJSON = jsonString
        EaselStorage.saveDocument(doc, id: id, profileID: profileID)
        // bump modified
        touchEasel(id: id)
    }

    // MARK: - Preview

    func savePreview(dataURL: String, id: UUID) {
        EaselStorage.savePreview(dataURL: dataURL, id: id, profileID: profileID)
        // trigger UI refresh — touch without reordering? Just objectWillChange
        // Easel list observes easels, but preview is file-based; force refresh via touch date
        if let idx = easels.firstIndex(where: { $0.id == id }) {
            easels[idx].modifiedAt = Date()
        }
    }

    func previewImage(for id: UUID) -> NSImage? {
        EaselStorage.loadPreviewImage(id: id, profileID: profileID)
    }

    private func persistIndex() {
        guard isPersistenceEnabled else { return }
        EaselStorage.saveIndex(easels, profileID: profileID)
    }
}
