//
//  ContainerCleanup.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/5/26.
//

import Foundation
import WebKit

enum ContainerCleanup {
    nonisolated static let cleanupInterval: TimeInterval = 24 * 60 * 60
    nonisolated static let cacheDecayThreshold: TimeInterval = 30 * 24 * 60 * 60

    nonisolated static func cleanupContainersIfNeeded() {
        let defaults = UserDefaults.standard
        let lastCleanupKey = "container.cleanup.lastRun"
        let lastRun = defaults.object(forKey: lastCleanupKey) as? Date ?? .distantPast
        let now = Date()

        guard now.timeIntervalSince(lastRun) > cleanupInterval else { return }

        defaults.set(now, forKey: lastCleanupKey)

        Task.detached(priority: .background) {
            cleanupFaviconDiskCache()
            cleanupBackgroundImageCache()
            cleanupStaleTabAssets()
        }
    }

    nonisolated static func cleanupFaviconDiskCache() {
        let cacheURL = FileManager.default
            .illuminateAppSupportDirectory()
            .appendingPathComponent("Favicons", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ), !files.isEmpty else { return }

        let cutoff = Date().addingTimeInterval(-cacheDecayThreshold)
        var removedCount = 0
        var removedBytes: UInt64 = 0

        for file in files where file.pathExtension == "png" {
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]) else { continue }
            guard let modDate = attrs.contentModificationDate, modDate < cutoff else { continue }

            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try? FileManager.default.removeItem(at: file)
            removedCount += 1
            removedBytes += UInt64(size)
        }

        if removedCount > 0 {
            AppLog.info("Cleaned favicon cache: removed \(removedCount) files, \(removedBytes / 1024 / 1024)MB")
        }
    }

    nonisolated static func cleanupBackgroundImageCache() {
        let cacheURL = FileManager.default
            .illuminateAppSupportDirectory()
            .appendingPathComponent("Backgrounds", isDirectory: true)

        guard FileManager.default.fileExists(atPath: cacheURL.path),
              let files = try? FileManager.default.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
              ), !files.isEmpty
        else { return }

        let cutoff = Date().addingTimeInterval(-cacheDecayThreshold)
        let maxCacheSize: Int64 = 500 * 1024 * 1024
        var removedCount = 0
        var removedBytes: UInt64 = 0
        var totalSize: Int64 = 0
        var datedFiles: [(URL, Date, Int64)] = []

        for file in files where ["jpg", "png"].contains(file.pathExtension.lowercased()) {
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { continue }
            let modDate = attrs.contentModificationDate ?? .distantPast
            let size = Int64(attrs.fileSize ?? 0)
            totalSize += size
            datedFiles.append((file, modDate, size))
        }

        let sorted = datedFiles.sorted { $0.1 < $1.1 }

        for (file, modDate, size) in sorted {
            if totalSize <= maxCacheSize && modDate >= cutoff {
                break
            }
            try? FileManager.default.removeItem(at: file)
            removedCount += 1
            removedBytes += UInt64(size)
            totalSize -= size
        }

        if removedCount > 0 {
            AppLog.info("Cleaned background image cache: removed \(removedCount) files, \(removedBytes / 1024 / 1024)MB")
        }
    }

    nonisolated static func cleanupStaleTabAssets() {
        let tabAssetsBaseURL = FileManager.default
            .illuminateAppSupportDirectory()
            .appendingPathComponent("TabAssets", isDirectory: true)

        guard FileManager.default.fileExists(atPath: tabAssetsBaseURL.path),
              let directories = try? FileManager.default.contentsOfDirectory(
                at: tabAssetsBaseURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: .skipsHiddenFiles
              ), !directories.isEmpty
        else { return }

        let cutoff = Date().addingTimeInterval(-cacheDecayThreshold)
        let maxAgeForMetadata: TimeInterval = 7 * 24 * 60 * 60
        let maxTabAssetsSize: Int64 = 100 * 1024 * 1024
        var removedCount = 0
        var removedBytes: UInt64 = 0
        var totalSize: Int64 = 0
        var datedDirs: [(URL, Date, Int64)] = []

        for dir in directories {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir == true else { continue }
            guard let attrs = try? dir.resourceValues(forKeys: [.contentModificationDateKey]) else { continue }
            let modDate = attrs.contentModificationDate ?? .distantPast
            let size = directoryTotalSize(at: dir)
            totalSize += size
            datedDirs.append((dir, modDate, size))
        }

        let sorted = datedDirs.sorted { $0.1 < $1.1 }

        for (dir, modDate, size) in sorted {
            if totalSize <= maxTabAssetsSize && modDate >= cutoff && Date().timeIntervalSince(modDate) < maxAgeForMetadata {
                break
            }
            try? FileManager.default.removeItem(at: dir)
            removedCount += 1
            removedBytes += UInt64(size)
            totalSize -= size
        }

        if removedCount > 0 {
            AppLog.info("Cleaned stale tab assets: removed \(removedCount) folders, \(removedBytes / 1024 / 1024)MB")
        }
    }

    nonisolated static func directoryTotalSize(at url: URL) -> Int64 {
        var total: Int64 = 0
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard
                let attrs = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                attrs.isRegularFile == true
            else { continue }
            total += Int64(attrs.fileSize ?? 0)
        }
        return total
    }

    @MainActor
    static func cleanupWebsiteDataStore(for profileID: UUID?) {
        guard let profileID else { return }
        let dataStore = WKWebsiteDataStore(forIdentifier: profileID)
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: cutoff) {
            AppLog.info("Cleaned website data store for profile \(profileID.uuidString): removed records older than 7 days")
        }
    }
}
