//
//  FaviconCache.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import AppKit
import Foundation

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

    private let lock = NSLock()
    private let cacheURL: URL
    private let fetchData: @Sendable (String) async throws -> Data
    private let inFlightRequests = AsyncRequestDeduplicator<String, Data>()

    nonisolated init(
        capacity: Int,
        cacheDirectory: URL? = nil,
        fetchData: (@Sendable (String) async throws -> Data)? = nil
    ) {
        self.capacity = max(8, capacity)
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
        lock.lock()
        if let cached = storage[key] {
            touch(key)
            lock.unlock()
            return cached
        }
        lock.unlock()

        if let diskImage = loadFromDisk(key) {
            return storeIfAbsent(diskImage, for: key)
        }

        return nil
    }

    nonisolated func memoryImage(for key: URL) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        guard let cached = storage[key] else { return nil }
        touch(key)
        return cached
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
        lock.lock()
        defer { lock.unlock() }
        if let cached = storage[key] {
            touch(key)
            return cached
        }
        storage[key] = newImage
        touch(key)
        evictIfNeeded()
        return newImage
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

    nonisolated private static func decodeAndEncode(_ data: Data) async -> (NSImage, Data?)? {
        await Task.detached(priority: .utility) { () -> (NSImage, Data?)? in
            guard let img = NSImage(data: data) else { return nil }
            return (img, img.pngData())
        }.value
    }

    nonisolated func performInline_set(_ image: NSImage, for key: URL) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = image
        touch(key)
        evictIfNeeded()
    }

    nonisolated private func setWithData(_ image: NSImage, pngData: Data?, for key: URL) {
        lock.lock()
        defer { lock.unlock() }

        storage[key] = image
        touch(key)
        if let data = pngData {
            persistToDisk(data, at: diskURL(for: key))
        }
        evictIfNeeded()
    }

    nonisolated func touch(_ key: URL) {
        accessCounter &+= 1
        accessOrder[key] = accessCounter
    }

    nonisolated private func evictIfNeeded() {
        while accessOrder.count > capacity {
            var oldestKey: URL?
            var oldestSeq: UInt64 = .max
            for (url, seq) in accessOrder {
                if seq < oldestSeq {
                    oldestSeq = seq
                    oldestKey = url
                }
            }
            if let oldest = oldestKey {
                accessOrder.removeValue(forKey: oldest)
                storage.removeValue(forKey: oldest)
            } else {
                break
            }
        }
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
        Task.detached(priority: .userInitiated) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
    
    nonisolated private func loadFromDisk(_ key: URL) -> NSImage? {
        let url = diskURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let image = NSImage(data: data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return image
    }

}
