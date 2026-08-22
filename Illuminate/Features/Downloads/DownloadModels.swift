//
//  DownloadModels.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/4/26.
//

import Foundation

enum DownloadState: String, Codable, Sendable {
    case preparing
    case downloading
    case completed
    case failed
    case cancelled
}

struct DownloadPreferences: Codable, Equatable, Sendable {
    var revealInFinderWhenFinished: Bool
    var saveLocationBookmarkData: Data?
    var askWhereToSave: Bool
    var lastPickedDirectoryBookmarkData: Data?

    init(
        revealInFinderWhenFinished: Bool = false,
        saveLocationBookmarkData: Data? = nil,
        askWhereToSave: Bool = false,
        lastPickedDirectoryBookmarkData: Data? = nil
    ) {
        self.revealInFinderWhenFinished = revealInFinderWhenFinished
        self.saveLocationBookmarkData = saveLocationBookmarkData
        self.askWhereToSave = askWhereToSave
        self.lastPickedDirectoryBookmarkData = lastPickedDirectoryBookmarkData
    }
}

struct DownloadTask: Identifiable, Sendable {
    let id: UUID
    let url: URL
    var filename: String
    var progress: Double
    var state: DownloadState
    var errorDescription: String?
    var destinationURL: URL?
    var bytesWritten: Int64
    var totalBytesExpected: Int64?
    let createdAt: Date
    var finishedAt: Date?

    var isCompleted: Bool { state == .completed }
    var isFailed: Bool { state == .failed }
    var isActive: Bool { state == .preparing || state == .downloading }

    var statusDescription: String {
        switch state {
        case .preparing:
            return "Preparing"
        case .downloading:
            if let totalBytesExpected, totalBytesExpected > 0 {
                let written = ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: totalBytesExpected, countStyle: .file)
                return "\(written) of \(total)"
            }
            if bytesWritten > 0 {
                return ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)
            }
            return "Starting"
        case .completed:
            if let destinationURL {
                return destinationURL.lastPathComponent
            }
            return "Completed"
        case .failed:
            return errorDescription ?? "Download failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}
