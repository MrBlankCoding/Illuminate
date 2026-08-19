//
//  DownloadManagerHelpers.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/4/26.
//

import Combine
import Foundation
import UniformTypeIdentifiers

extension DownloadManager {
    func clearFinishedDownloads() {
        downloads.removeAll { !$0.isActive }
        rebuildIndexMap()
        notifyDownloadsDidChange(immediate: true)
    }

    func clearDownloads() {
        downloads.removeAll()
        downloadIndexMap.removeAll()
        notifyDownloadsDidChange(immediate: true)
    }

    internal func rebuildIndexMap() {
        var map = [UUID: Int]()
        map.reserveCapacity(downloads.count)
        for (index, task) in downloads.enumerated() {
            map[task.id] = index
        }
        self.downloadIndexMap = map
    }

    func makeTask(
        url: URL,
        filename: String,
        destinationURL: URL?
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
            finishedAt: nil
        )
    }

    func insertTask(_ task: DownloadTask) {
        markSessionHasDownload()
        downloads.insert(task, at: 0)
        rebuildIndexMap()
        AppLog.download("Inserted download item id=\(task.id.uuidString) source=\(task.url.absoluteString) filename=\(task.filename) state=\(task.state.rawValue)")
        notifyDownloadsDidChange(immediate: true)
    }

    func updateTask(_ id: UUID, mutate: @escaping (inout DownloadTask) -> Void) {
        guard let index = downloadIndexMap[id] else { return }
        mutate(&downloads[index])
        notifyDownloadsDidChange(immediate: false)
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
        noteCompletedDownload()

        if preferences.revealInFinderWhenFinished,
           let task = downloads.first(where: { $0.id == id }) {
            revealDownload(task)
        }
    }

    func failDownload(id: UUID, error: Error) {
        AppLog.error("Download failed id=\(id.uuidString)", error: error)
        updateTask(id) { task in
            task.state = .failed
            task.finishedAt = Date()
            task.errorDescription = error.localizedDescription
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

        let preferredExtension: String?
        if let fallbackURL,
           !fallbackURL.pathExtension.isEmpty,
           let fallbackExtension = fallbackURL.pathExtension.lowercased().nilIfEmpty {
            preferredExtension = fallbackExtension
        } else if let mimeType,
                  let type = UTType(mimeType: mimeType),
                  let fallbackExtension = type.preferredFilenameExtension?.lowercased() {
            preferredExtension = fallbackExtension
        } else {
            preferredExtension = nil
        }

        if let preferredExtension {
            let normalizedPreferred = preferredExtension.lowercased()
            let currentExtension = (filename as NSString).pathExtension.lowercased()

            if currentExtension.isEmpty {
                filename = "\(filename).\(normalizedPreferred)"
            } else if currentExtension != normalizedPreferred {
                if let fallbackURL,
                   !fallbackURL.pathExtension.isEmpty,
                   fallbackURL.pathExtension.lowercased() == normalizedPreferred,
                   !fallbackURL.lastPathComponent.isEmpty {
                    filename = fallbackURL.lastPathComponent
                } else {
                    let extensionless = (filename as NSString).deletingPathExtension
                    let withoutDuplicateSuffix = extensionless.replacingOccurrences(
                        of: #" \(\d+\)\.[^.]+$"#,
                        with: "",
                        options: .regularExpression
                    )
                    let baseName = withoutDuplicateSuffix.isEmpty ? extensionless : withoutDuplicateSuffix
                    filename = "\(baseName).\(normalizedPreferred)"
                }
            }
        }

        let resolvedExtension = (filename as NSString).pathExtension
        if resolvedExtension.isEmpty,
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

        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let duplicateName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            destinationURL = directory.appendingPathComponent(duplicateName, isDirectory: false)
            counter += 1
        }

        AppLog.download("Resolved unique destination directory=\(directory.path) preferredFilename=\(preferredFilename) finalPath=\(destinationURL.path)")
        return destinationURL
    }


    nonisolated func ensureParentDirectoryExists(for destinationURL: URL) throws {
        try ensureDirectoryExists(at: destinationURL.deletingLastPathComponent())
    }

    nonisolated func ensureDirectoryExists(at directoryURL: URL) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    nonisolated func stageDownloadedFile(at location: URL) -> URL? {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        let stagingDirectory = baseDirectory
            .appendingPathComponent("Illuminate", isDirectory: true)
            .appendingPathComponent("DownloadStaging", isDirectory: true)
        do {
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            let stagingURL = stagingDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.moveItem(at: location, to: stagingURL)
            return stagingURL
        } catch {
            AppLog.error("Failed to stage downloaded file path=\(location.path)", error: error)
            return nil
        }
    }

    nonisolated func moveDownload(at temporaryURL: URL, to destinationURL: URL) throws {
        try ensureParentDirectoryExists(for: destinationURL)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
    }

    func notifyDownloadsDidChange(immediate: Bool = false) {
        if immediate {
            notificationThrottleTask?.cancel()
            notificationThrottleTask = nil
            dispatchNotification()
        } else {
            if notificationThrottleTask != nil { return }
            notificationThrottleTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.notificationThrottleTask = nil
                self.dispatchNotification()
            }
        }
    }

    private func dispatchNotification() {
        self.objectWillChange.send()
        NotificationCenter.default.post(
            name: Self.downloadsDidChangeNotification,
            object: self,
            userInfo: [
                "hasActiveDownloads": downloads.contains(where: \.isActive),
                "hasVisibleDownloads": !downloads.isEmpty,
                "hasRecentCompletedDownload": hasRecentCompletedDownload
            ]
        )
    }


}
