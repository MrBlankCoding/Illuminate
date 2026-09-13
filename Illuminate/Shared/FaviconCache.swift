//
//  FaviconCache.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import AppKit
import Foundation

final class FaviconCache: @unchecked Sendable {
    nonisolated static let shared = FaviconCache(capacity: 128)

    private let capacity: Int
    nonisolated(unsafe) var storage: [URL: NSImage] = [:]
    nonisolated(unsafe) var accessOrder: [URL: UInt64] = [:]
    nonisolated(unsafe) var accessCounter: UInt64 = 0
    // Guarded by `lock`.
    nonisolated(unsafe) var protectedKeys: Set<String> = []

    private let lock = NSLock()
    private let cacheURL: URL
    private nonisolated static let maxDiskEntries = 512
    private nonisolated static let maxDiskSizeBytes: Int64 = 50 * 1024 * 1024
    private nonisolated static let diskCacheTTL: TimeInterval = 7 * 24 * 60 * 60
    private nonisolated(unsafe) static var pendingDiskPrune = false
    nonisolated init(
        capacity: Int,
        cacheDirectory: URL? = nil
    ) {
        self.capacity = max(1, capacity)
        if let customDir = cacheDirectory {
            self.cacheURL = customDir
        } else {
            cacheURL = FileManager.default
                .illuminateAppSupportDirectory()
                .appendingPathComponent("Favicons", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }

    nonisolated func image(for key: URL) -> NSImage? {
        let cached: NSImage? = lock.withLock {
            if let cached = storage[key] {
                touch(key)
                return cached
            }
            return nil
        }

        if let cached = cached {
            return cached
        }

        if let diskImage = loadFromDisk(key) {
            return storeIfAbsent(diskImage, for: key)
        }

        return nil
    }

    nonisolated func memoryImage(for key: URL) -> NSImage? {
        lock.withLock {
            guard let cached = storage[key] else { return nil }
            touch(key)
            return cached
        }
    }

    nonisolated func imageIncludingDisk(for key: URL) async -> NSImage? {
        if let cached = memoryImage(for: key) { return cached }
        return await Task.detached(priority: .utility) { [weak self] in
            guard let self else { return nil }
            if let diskImage = self.loadFromDisk(key) {
                return self.storeIfAbsent(diskImage, for: key)
            }
            return nil
        }.value
    }

    nonisolated private func storeIfAbsent(_ newImage: NSImage, for key: URL) -> NSImage {
        return lock.withLock {
            if let cached = storage[key] {
                touch(key)
                return cached
            }
            storage[key] = newImage
            touch(key)
            evictIfNeeded()
            return newImage
        }
    }

    nonisolated private func normalizedRequestKey(for url: URL) -> String {
        let s = url.absoluteString
        return s.isEmpty ? "INVALID_URL" : s
    }

    nonisolated func performInline_set(_ image: NSImage, for key: URL) {
        lock.withLock {
            storage[key] = image
            touch(key)
            evictIfNeeded()
        }
    }

    nonisolated func removeAll(matchingScheme scheme: String, host: String) {
        let scheme = scheme.lowercased()
        var diskHashes: [String] = []
        lock.withLock {
            let matching = storage.keys.filter {
                $0.scheme?.lowercased() == scheme && $0.host == host
            }
            for key in matching {
                storage.removeValue(forKey: key)
                accessOrder.removeValue(forKey: key)
                diskHashes.append(stableHash(normalizedRequestKey(for: key)))
            }
        }
        guard !diskHashes.isEmpty else { return }
        Task.detached(priority: .utility) { [cacheURL] in
            for hash in diskHashes {
                let path = cacheURL.appendingPathComponent(hash).appendingPathExtension("png").path
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    nonisolated func touch(_ key: URL) {
        accessCounter &+= 1
        accessOrder[key] = accessCounter
    }

    nonisolated private func evictIfNeeded() {
        while accessOrder.count > capacity {
            let oldest = oldestAccessKey(preferUnprotected: true)
                ?? oldestAccessKey(preferUnprotected: false)
            guard let oldest else { break }
            accessOrder.removeValue(forKey: oldest)
            storage.removeValue(forKey: oldest)
        }
    }

    nonisolated private func oldestAccessKey(preferUnprotected: Bool) -> URL? {
        var oldestKey: URL?
        var oldestSeq: UInt64 = .max
        for (url, seq) in accessOrder {
            let isProtected = isProtectedKey(normalizedRequestKey(for: url))
            let matchesPreference = preferUnprotected ? !isProtected : isProtected
            guard matchesPreference, seq < oldestSeq else { continue }
            oldestSeq = seq
            oldestKey = url
        }
        return oldestKey
    }

    nonisolated func setProtectedURLs(_ urls: [URL]) {
        lock.withLock {
            protectedKeys = Set(urls.map { normalizedRequestKey(for: $0) })
        }
    }

    nonisolated private func isProtectedKey(_ key: String) -> Bool {
        protectedKeys.contains(key)
    }

    nonisolated private func diskURL(for key: URL) -> URL {
        let name = normalizedRequestKey(for: key)
        let hash = stableHash(name)
        return cacheURL.appendingPathComponent(hash).appendingPathExtension("png")
    }

    nonisolated private func stableHash(_ string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }

    nonisolated private static func pruneDiskCacheIfNeeded(directory: URL, protectedHashes: Set<String>) async {
        dispatchPrecondition(condition: .notOnQueue(.main))
        let shouldPrune = lockPrune.withLock {
            if pendingDiskPrune {
                return false
            }
            pendingDiskPrune = true
            return true
        }

        guard shouldPrune else { return }

        defer {
            lockPrune.withLock {
                pendingDiskPrune = false
            }
        }

        let now = Date()
        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let resourceKeySet = Set(resourceKeys)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: .skipsHiddenFiles
        ) else { return }

        let entries = files.compactMap { file -> (url: URL, date: Date, size: Int64, isProtected: Bool, isExpired: Bool)? in
            let values = try? file.resourceValues(forKeys: resourceKeySet)
            let date = values?.contentModificationDate ?? .distantPast
            let size = values?.fileSize ?? 0
            let isProtected = protectedHashes.contains(file.deletingPathExtension().lastPathComponent)
            let isExpired = now.timeIntervalSince(date) > diskCacheTTL
            return (file, date, Int64(size), isProtected, isExpired)
        }

        let totalSize = entries.reduce(0) { $0 + $1.size }
        let shouldPruneByCount = entries.count > maxDiskEntries
        let shouldPruneBySize = totalSize > maxDiskSizeBytes
        var expiredRemaining = entries.reduce(0) { $0 + ($1.isExpired ? 1 : 0) }

        guard shouldPruneByCount || shouldPruneBySize || expiredRemaining > 0 else { return }

        let sorted = entries.sorted { lhs, rhs in
            if lhs.isProtected != rhs.isProtected { return !lhs.isProtected }
            return lhs.date < rhs.date
        }

        var removedCount = 0
        var runningTotalSize = totalSize

        for entry in sorted {
            if entry.isProtected && !entry.isExpired { continue }

            let overCount = entries.count - removedCount > maxDiskEntries
            let overSize = runningTotalSize > maxDiskSizeBytes
            guard overCount || overSize || entry.isExpired else { break }

            try? FileManager.default.removeItem(at: entry.url)
            removedCount += 1
            runningTotalSize -= entry.size
            if entry.isExpired { expiredRemaining -= 1 }

            if entries.count - removedCount <= maxDiskEntries
                && runningTotalSize <= maxDiskSizeBytes
                && expiredRemaining <= 0 {
                break
            }
        }
    }
    private nonisolated static let lockPrune = NSLock()

    nonisolated private func loadFromDisk(_ key: URL) -> NSImage? {
        let url = diskURL(for: key)
        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let resourceKeySet = Set(resourceKeys)
        guard
            let values = try? url.resourceValues(forKeys: resourceKeySet),
            let modificationDate = values.contentModificationDate
        else { return nil }

        if Date().timeIntervalSince(modificationDate) > Self.diskCacheTTL {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
        guard let image = NSImage(data: data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return image
    }

}
