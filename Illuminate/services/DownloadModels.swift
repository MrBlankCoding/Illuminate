//
//  DownloadModels.swift
//  Illuminate
//

import Foundation

enum DownloadState: String, Codable, Sendable {
    case preparing
    case downloading
    case completed
    case failed
    case cancelled
    case blocked
}

enum DownloadSafetyLevel: String, Codable, Sendable {
    case safe
    case caution
    case blocked
}

struct DownloadPreferences: Codable, Equatable, Sendable {
    var safeDownloadsOnly: Bool
    var revealInFinderWhenFinished: Bool
    var saveLocationBookmarkData: Data?

    init(
        safeDownloadsOnly: Bool = true,
        revealInFinderWhenFinished: Bool = false,
        saveLocationBookmarkData: Data? = nil
    ) {
        self.safeDownloadsOnly = safeDownloadsOnly
        self.revealInFinderWhenFinished = revealInFinderWhenFinished
        self.saveLocationBookmarkData = saveLocationBookmarkData
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
    var safetyLevel: DownloadSafetyLevel

    var isCompleted: Bool { state == .completed }
    var isFailed: Bool { state == .failed || state == .blocked }
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
        case .blocked:
            return errorDescription ?? "Blocked by download protection"
        }
    }
}
