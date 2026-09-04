//
//  FaviconCache.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import AppKit
import Foundation
import Nuke

final class FaviconCache: @unchecked Sendable {
    private enum FaviconFetchError: LocalizedError {
        case unsupportedScheme(String?)
        case invalidDataURL

        var errorDescription: String? {
            switch self {
            case .unsupportedScheme(let scheme):
                return "Unsupported favicon URL scheme: \(scheme ?? "nil")"
            case .invalidDataURL:
                return "Invalid favicon data URL"
            }
        }
    }

    private enum DataURLDecoder {
        nonisolated static func decode(_ rawURL: String) -> Data? {
            guard rawURL.hasPrefix("data:"),
                  let commaIndex = rawURL.firstIndex(of: ",")
            else {
                return nil
            }

            let metadata = rawURL[..<commaIndex]
            let payload = String(rawURL[rawURL.index(after: commaIndex)...])

            if metadata.localizedCaseInsensitiveContains(";base64") {
                let cleanPayload = payload.removingPercentEncoding ?? payload
                return Data(base64Encoded: cleanPayload, options: .ignoreUnknownCharacters)
            }

            return (payload.removingPercentEncoding ?? payload).data(using: .utf8)
        }
    }

    nonisolated static let shared = FaviconCache(capacity: 128)

    private let capacity: Int
    nonisolated(unsafe) var storage: [URL: NSImage] = [:]
    nonisolated(unsafe) var accessOrder: [URL: UInt64] = [:]
    nonisolated(unsafe) var accessCounter: UInt64 = 0
    // Guarded by `lock`.
    nonisolated(unsafe) var protectedKeys: Set<String> = []

    private let lock = NSLock()
    private let cacheURL: URL
    private static let maxDiskEntries = 512
    private nonisolated(unsafe) static var pendingDiskPrune = false
    private let fetchData: @Sendable (String) async throws -> Data
    private let inFlightRequests = AsyncRequestDeduplicator<String, Data>()

    nonisolated init(
        capacity: Int,
        cacheDirectory: URL? = nil,
        fetchData: (@Sendable (String) async throws -> Data)? = nil
    ) {
        self.capacity = max(1, capacity) // 8?
        if let fetchData {
            self.fetchData = fetchData
        } else {
            self.fetchData = { rawURL in
                if rawURL.hasPrefix("data:") {
                    guard let data = DataURLDecoder.decode(rawURL) else {
                        throw FaviconFetchError.invalidDataURL
                    }
                    return data
                }

                guard let url = URL(string: rawURL) else {
                    throw FaviconFetchError.invalidDataURL
                }

                switch url.scheme?.lowercased() {
                case "http", "https":
                    if let nukeImage = try? await BrowserImageLoader.shared.loadImage(from: url) {
                        if let png = await MainActor.run(body: { nukeImage.pngData() }) {
                            return png
                        }
                    }
                    let (data, _) = try await Task.detached(priority: .utility) {
                        try await URLSession.shared.data(from: url)
                    }.value
                    return data
                // this is our icon
                // dont cache
                case "webkit-extension":
                    throw FaviconFetchError.unsupportedScheme(url.scheme)
                default:
                    throw FaviconFetchError.unsupportedScheme(url.scheme)
                }
            }
        }
        
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

    nonisolated func fetchImage(for url: URL) async -> NSImage? {
        if let cached = await imageIncludingDisk(for: url) {
            return cached
        }

        if url.scheme?.lowercased() == "data" {
            guard let data = DataURLDecoder.decode(url.absoluteString) else { return nil }
            guard let result = await Self.decodeAndEncode(data) else {
                return nil
            }
            let (fetchedImage, pngData) = result

            if let cached = memoryImage(for: url) { return cached }
            setWithData(fetchedImage, pngData: pngData, for: url)
            return fetchedImage
        }

        let requestKey = normalizedRequestKey(for: url)

        do {
            let data = try await inFlightRequests.value(for: requestKey) { [fetchData] key in
                return try await fetchData(key)
            }

            guard let result = await Self.decodeAndEncode(data) else {
                return nil
            }
            let (fetchedImage, pngData) = result

            if let cached = memoryImage(for: url) { return cached }
            setWithData(fetchedImage, pngData: pngData, for: url)
            return fetchedImage
        } catch {
        }
        return nil
    }

    nonisolated private func normalizedRequestKey(for url: URL) -> String {
        let s = url.absoluteString
        return s.isEmpty ? "INVALID_URL" : s
    }

    private static let maxCachedPixelSize: CGFloat = 64

    nonisolated private static func decodeAndEncode(_ data: Data) async -> (NSImage, Data?)? {
        await Task.detached(priority: .utility) { () -> (NSImage, Data?)? in
            guard let img = NSImage(data: data) else { return nil }
            let resized = await downsampled(img, maxPixel: maxCachedPixelSize)
            let pngData = await MainActor.run { resized.pngData() }
            return (resized, pngData)
        }.value
    }

    nonisolated private static func downsampled(_ image: NSImage, maxPixel: CGFloat) -> NSImage {
        let largestDimension = max(image.size.width, image.size.height)
        guard largestDimension > maxPixel, largestDimension > 0 else { return image }

        let scale = maxPixel / largestDimension
        let targetPixelsWide = max(1, Int((image.size.width * scale).rounded(.down)))
        let targetPixelsHigh = max(1, Int((image.size.height * scale).rounded(.down)))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetPixelsWide,
            pixelsHigh: targetPixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return image }

        rep.size = NSSize(width: targetPixelsWide, height: targetPixelsHigh)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(
            in: NSRect(x: 0, y: 0, width: targetPixelsWide, height: targetPixelsHigh),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: NSSize(width: targetPixelsWide, height: targetPixelsHigh))
        result.addRepresentation(rep)
        return result
    }

    nonisolated func performInline_set(_ image: NSImage, for key: URL) {
        lock.withLock {
            storage[key] = image
            touch(key)
            evictIfNeeded()
        }
    }

    nonisolated private func setWithData(_ image: NSImage, pngData: Data?, for key: URL) {
        let diskPath = diskURL(for: key)
        let hashes = lock.withLock {
            storage[key] = image
            touch(key)
            let h = Set(protectedKeys.map { stableHash($0) })
            evictIfNeeded()
            return h
        }
        if let data = pngData {
            Task.detached(priority: .userInitiated) { [cacheURL] in
                try? data.write(to: diskPath, options: .atomic)
                await Self.pruneDiskCacheIfNeeded(directory: cacheURL, protectedHashes: hashes)
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
            if seq < oldestSeq, isProtectedKey(normalizedRequestKey(for: url)) != preferUnprotected {
                oldestSeq = seq
                oldestKey = url
            }
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
    
    nonisolated private func persistToDisk(_ data: Data, at fileURL: URL) {
        // Caller holds `lock`; snapshot protection state before detaching.
        let hashes = Set(protectedKeys.map { stableHash($0) })
        Task.detached(priority: .userInitiated) { [cacheURL] in
            try? data.write(to: fileURL, options: .atomic)
            await Self.pruneDiskCacheIfNeeded(directory: cacheURL, protectedHashes: hashes)
        }
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

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ), await files.count > maxDiskEntries else { return }

        let dated = files.map { file -> (URL, Date, Bool) in
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let isProtected = protectedHashes.contains(file.deletingPathExtension().lastPathComponent)
            return (file, date, isProtected)
        }

        let sorted = dated.sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return !lhs.2 }
            return lhs.1 < rhs.1
        }
        let excess = await sorted.prefix(files.count - maxDiskEntries)
        for (file, _, _) in excess {
            try? FileManager.default.removeItem(at: file)
        }
    }
    private nonisolated static let lockPrune = NSLock()

    nonisolated private func loadFromDisk(_ key: URL) -> NSImage? {
        let url = diskURL(for: key)
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
