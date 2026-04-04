//
//  DownloadManager+Helpers.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/4/26.
//

import Foundation
import UniformTypeIdentifiers

extension DownloadManager {
    func clearFinishedDownloads() {
        updateOnMain {
            self.downloads.removeAll { !$0.isActive }
            self.notifyDownloadsDidChange()
        }
    }

    func clearDownloads() {
        updateOnMain {
            self.downloads.removeAll()
            self.notifyDownloadsDidChange()
        }
    }

    func makeTask(
        url: URL,
        filename: String,
        destinationURL: URL?,
        safetyLevel: DownloadSafetyLevel
    ) -> DownloadTask {
        DownloadTask(
            id: UUID(),
            url: url,
            filename: sanitizedFilename(filename, fallbackURL: url),
            progress: 0,
            state: .preparing,
            errorDescription: nil,
            destinationURL: destinationURL,
            bytesWritten: 0,
            totalBytesExpected: nil,
            createdAt: Date(),
            finishedAt: nil,
            safetyLevel: safetyLevel
        )
    }

    func insertTask(_ task: DownloadTask) {
        updateOnMain {
            self.downloads.insert(task, at: 0)
            AppLog.download("Inserted download item id=\(task.id.uuidString) source=\(task.url.absoluteString) filename=\(task.filename) state=\(task.state.rawValue)")
            self.notifyDownloadsDidChange()
        }
    }

    func updateTask(_ id: UUID, mutate: @escaping (inout DownloadTask) -> Void) {
        updateOnMain {
            guard let index = self.downloads.firstIndex(where: { $0.id == id }) else { return }
            mutate(&self.downloads[index])
            self.notifyDownloadsDidChange()
        }
    }

    func finishDownload(id: UUID, destinationURL: URL) {
        AppLog.download("Finishing download id=\(id.uuidString) destination=\(destinationURL.path)")
        updateTask(id) { task in
            task.destinationURL = destinationURL
            task.filename = destinationURL.lastPathComponent
            task.progress = 1
            task.state = .completed
            task.finishedAt = Date()
            task.errorDescription = nil
            task.bytesWritten = task.totalBytesExpected ?? task.bytesWritten
        }

        if preferences.revealInFinderWhenFinished {
            updateOnMain {
                if let task = self.downloads.first(where: { $0.id == id }) {
                    self.revealDownload(task)
                }
            }
        }
    }

    func failDownload(id: UUID, error: Error) {
        AppLog.download("Download failed id=\(id.uuidString) error=\(error.localizedDescription)")
        updateTask(id) { task in
            task.state = .failed
            task.finishedAt = Date()
            task.errorDescription = error.localizedDescription
        }
    }

    func markBlocked(id: UUID, message: String) {
        AppLog.download("Download blocked id=\(id.uuidString) reason=\(message)")
        updateTask(id) { task in
            task.state = .blocked
            task.finishedAt = Date()
            task.errorDescription = message
            task.safetyLevel = .blocked
        }
    }

    func resolvedExplicitDestination(for destinationURL: URL) -> URL {
        let filename = sanitizedFilename(destinationURL.lastPathComponent, fallbackURL: destinationURL)
        let directory = destinationURL.deletingLastPathComponent()
        let resolvedURL = uniqueDestinationURL(in: directory, preferredFilename: filename)
        AppLog.download("Resolved explicit destination requested=\(destinationURL.path) resolved=\(resolvedURL.path)")
        return resolvedURL
    }

    func resolvedFilename(_ rawFilename: String?, fallbackURL: URL?, mimeType: String?) -> String {
        var filename = sanitizedFilename(rawFilename, fallbackURL: fallbackURL)
        let pathExtension = (filename as NSString).pathExtension

        if pathExtension.isEmpty,
           let mimeType,
           let type = UTType(mimeType: mimeType),
           let preferredExtension = type.preferredFilenameExtension
        {
            filename.append(".\(preferredExtension)")
        }

        AppLog.download("Resolved filename raw=\(rawFilename ?? "<nil>") fallback=\(fallbackURL?.absoluteString ?? "<nil>") mimeType=\(mimeType ?? "<nil>") resolved=\(filename)")
        return filename
    }

    func sanitizedFilename(_ rawFilename: String?, fallbackURL: URL? = nil) -> String {
        let candidate = rawFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackCandidate = fallbackURL?.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseValue = [candidate, fallbackCandidate, "download"]
            .compactMap { $0 }
            .first { !$0.isEmpty && $0 != "." && $0 != ".." } ?? "download"

        let invalidScalars = CharacterSet(charactersIn: "/:\\?%*|\"<>\n\r\t").union(.controlCharacters)
        let sanitizedScalars = baseValue.unicodeScalars.map { invalidScalars.contains($0) ? "_" : Character($0) }
        let sanitized = String(sanitizedScalars).trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        return sanitized.isEmpty ? "download" : sanitized
    }

    func uniqueDestinationURL(in directory: URL, preferredFilename: String) -> URL {
        let safeFilename = sanitizedFilename(preferredFilename)
        var destinationURL = directory.appendingPathComponent(safeFilename, isDirectory: false)

        let name = (safeFilename as NSString).deletingPathExtension
        let ext = (safeFilename as NSString).pathExtension
        var counter = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            let duplicateName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            destinationURL = directory.appendingPathComponent(duplicateName, isDirectory: false)
            counter += 1
        }

        AppLog.download("Resolved unique destination directory=\(directory.path) preferredFilename=\(preferredFilename) finalPath=\(destinationURL.path)")
        return destinationURL
    }

    func shouldAllowDownload(filename: String, mimeType: String?, destinationURL: URL?) -> Bool {
        guard preferences.safeDownloadsOnly else { return true }
        return safetyLevel(for: filename, mimeType: mimeType, destinationURL: destinationURL) != .blocked
    }

    func safetyLevel(for filename: String, mimeType: String? = nil, destinationURL: URL? = nil) -> DownloadSafetyLevel {
        let dangerousExtensions: Set<String> = [
            "app", "command", "csh", "dmg", "iso", "kext", "mpkg", "osx", "pkg",
            "scpt", "sh", "tool", "workflow", "zsh"
        ]
        let cautionExtensions: Set<String> = [
            "bat", "bin", "dylib", "exe", "jar", "js", "msi", "py", "rb", "swift", "zip"
        ]
        let blockedMimePrefixes = ["application/x-apple-diskimage", "application/x-msdownload"]

        let pathExtension = (destinationURL?.pathExtension ?? (filename as NSString).pathExtension).lowercased()

        if dangerousExtensions.contains(pathExtension) {
            AppLog.download("Safety evaluation blocked by extension filename=\(filename) pathExtension=\(pathExtension) mimeType=\(mimeType ?? "<nil>")")
            return .blocked
        }

        if let mimeType, blockedMimePrefixes.contains(where: { mimeType.hasPrefix($0) }) {
            AppLog.download("Safety evaluation blocked by mimeType filename=\(filename) mimeType=\(mimeType)")
            return .blocked
        }

        if cautionExtensions.contains(pathExtension) {
            AppLog.download("Safety evaluation caution filename=\(filename) pathExtension=\(pathExtension)")
            return .caution
        }

        return .safe
    }

    func ensureParentDirectoryExists(for destinationURL: URL) throws {
        try ensureDirectoryExists(at: destinationURL.deletingLastPathComponent())
    }

    func ensureDirectoryExists(at directoryURL: URL) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func moveDownload(at temporaryURL: URL, to destinationURL: URL) throws {
        try ensureParentDirectoryExists(for: destinationURL)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    }

    func notifyDownloadsDidChange() {
        NotificationCenter.default.post(
            name: Self.downloadsDidChangeNotification,
            object: self,
            userInfo: [
                "hasActiveDownloads": downloads.contains(where: \.isActive),
                "hasVisibleDownloads": !downloads.isEmpty
            ]
        )
    }

    func updateOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
