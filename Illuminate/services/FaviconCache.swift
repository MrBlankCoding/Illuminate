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

    static let shared = FaviconCache(capacity: 128)

    private let capacity: Int
    nonisolated(unsafe) private var storage: [URL: NSImage] = [:]
    nonisolated(unsafe) private var order: [URL] = []
    private let lock = NSLock()
    private let cacheURL: URL
    private let fetchData: @Sendable (String) async throws -> Data
    private let inFlightRequests = AsyncRequestDeduplicator<String, Data>()

    init(
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
                    let (data, _) = try await URLSession.shared.data(from: url)
                    return data
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
        defer { lock.unlock() }

        if let cached = storage[key] {
            touch(key)
            return cached
        }
        
        // Try disk cache
        if let diskImage = loadFromDisk(key) {
            storage[key] = diskImage
            touch(key)
            return diskImage
        }

        return nil
    }

    nonisolated func fetchImage(for url: URL) async -> NSImage? {
        if let cached = image(for: url) {
            return cached
        }

        if url.scheme?.lowercased() == "data" {
            guard let data = DataURLDecoder.decode(url.absoluteString) else { return nil }
            // Compute pngData() inside MainActor.run — NSImage and tiffRepresentation
            // are not thread-safe; doing both together avoids an extra async hop.
            guard let result = await MainActor.run(body: { () -> (NSImage, Data?)? in
                guard let img = NSImage(data: data) else { return nil }
                return (img, img.pngData())
            }) else {
                return nil
            }
            let (fetchedImage, pngData) = result

            if let cached = image(for: url) { return cached }
            setWithData(fetchedImage, pngData: pngData, for: url)
            return fetchedImage
        }

        let requestKey = normalizedRequestKey(for: url)

        do {
            let data = try await inFlightRequests.value(for: requestKey) { [fetchData] key in
                return try await fetchData(key)
            }

            // Compute pngData() inside MainActor.run alongside NSImage creation.
            // This avoids dispatching back to MainActor later (which can starve
            // when the main actor is occupied by parallel WebKit tests).
            guard let result = await MainActor.run(body: { () -> (NSImage, Data?)? in
                guard let img = NSImage(data: data) else { return nil }
                return (img, img.pngData())
            }) else {
                return nil
            }
            let (fetchedImage, pngData) = result

            if let cached = image(for: url) { return cached }
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

    @MainActor func set(_ image: NSImage, for key: URL) {
        // Compute PNG data before acquiring the lock. This method is called from
        // @MainActor contexts (tests, UI callbacks), so tiffRepresentation is safe.
        // pngData() is intentionally NOT dispatched async — see persistToDisk().
        let pngData = image.pngData()
        setWithData(image, pngData: pngData, for: key)
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

    nonisolated private func touch(_ key: URL) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    nonisolated private func evictIfNeeded() {
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            storage.removeValue(forKey: oldest)
            removeFromDisk(oldest)
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
        // pngData() has already been computed on the correct thread by the caller.
        // This function only does pure I/O — safe to run on any thread.
        // .atomic writes to a temp file first, then renames, so readers never see
        // a partial PNG (which caused libpng IDAT CRC errors and cascading deletes).
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
    
    nonisolated private func removeFromDisk(_ key: URL) {
        let url = diskURL(for: key)
        try? FileManager.default.removeItem(at: url)
    }
}
