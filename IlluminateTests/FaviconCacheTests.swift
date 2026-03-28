//
//  FaviconCacheTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Testing
import AppKit
import Foundation
@testable import Illuminate

@MainActor
struct FaviconCacheTests {

    private func createTestImage() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.blue.set()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        return img
    }

    private func temporaryCacheDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitForPersistedPNG(in directory: URL, timeoutNanoseconds: UInt64 = 1_000_000_000) async throws -> URL {
        let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int64(timeoutNanoseconds)))

        while ContinuousClock.now < deadline {
            if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil),
               let pngURL = files.first(where: { $0.pathExtension == "png" }),
               let attributes = try? FileManager.default.attributesOfItem(atPath: pngURL.path),
               let fileSize = attributes[.size] as? NSNumber,
               fileSize.intValue > 0 {
                return pngURL
            }

            try await Task.sleep(nanoseconds: 20_000_000)
        }

        Issue.record("Timed out waiting for persisted favicon file in \(directory.path)")
        throw CancellationError()
    }

    private func waitForImagePersistence(
        at url: URL,
        in directory: URL,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async throws -> NSImage {
        let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int64(timeoutNanoseconds)))

        while ContinuousClock.now < deadline {
            let cache = FaviconCache(capacity: 10, cacheDirectory: directory)
            if let image = cache.image(for: url) {
                return image
            }

            try await Task.sleep(nanoseconds: 20_000_000)
        }

        Issue.record("Timed out waiting for persisted favicon image for \(url.absoluteString)")
        throw CancellationError()
    }
    
    private actor CounterFetcher {
        var count = 0
        let delay: UInt64
        let data: Data
        
        init(data: Data, delay: UInt64 = 0) {
            self.data = data
            self.delay = delay
        }
        
        func fetch(from urlString: String) async throws -> Data {
            count += 1
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            return data
        }
    }
    
    private actor RecordingFetcher {
        var urls: [String] = []
        let data: Data
        
        init(data: Data) { self.data = data }
        
        func fetch(from urlString: String) async throws -> Data {
            urls.append(urlString)
            return data
        }

        func recordedURLs() -> [String] {
            urls
        }
    }

    @Test func testCacheIsEmptyInitially() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "https://example.com/favicon.ico")!
        
        let retrieved = cache.image(for: url)
        #expect(retrieved == nil)
    }

    @Test func testSetAndRetrieve() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "https://example.com/favicon.ico")!
        
        let img = createTestImage()
        cache.set(img, for: url)
        
        let retrieved = cache.image(for: url)
        #expect(retrieved != nil)
    }

    @Test func testLRUEvictsOldestEntry() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 8, cacheDirectory: cacheDir)
        
        let urls = (1...9).map { URL(string: "https://site\($0).com")! }
        let img = createTestImage()
        
        for url in urls.prefix(8) {
            cache.set(img, for: url)
        }
        
        cache.set(img, for: urls[8])
        
        let first = cache.image(for: urls[0])
        #expect(first == nil, "Oldest element should be evicted")
        let second = cache.image(for: urls[1])
        #expect(second != nil, "Second element should still be present")
    }

    @Test func testLRUTouchPromotesEntry() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 8, cacheDirectory: cacheDir)
        
        let urls = (1...9).map { URL(string: "https://site\($0).com")! }
        let img = createTestImage()
        
        for url in urls.prefix(8) {
            cache.set(img, for: url)
        }
        
        // Touch first URL to make it newest
        _ = cache.image(for: urls[0])
        
        // Add 9th URL, which should evict urls[1] instead of urls[0]
        cache.set(img, for: urls[8])
        
        let first = cache.image(for: urls[0])
        #expect(first != nil, "Oldest touched element should not be evicted")
        let second = cache.image(for: urls[1])
        #expect(second == nil, "Second element should be evicted instead")
    }

    @Test func testDiskPersistenceAcrossInstances() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "https://persist-test.com")!
        
        let img = createTestImage()
        cache.set(img, for: url)
        _ = try await waitForImagePersistence(at: url, in: cacheDir)
    }

    @Test func testCorruptDiskDataIsCleanedUp() async throws {
        let cacheDir = temporaryCacheDirectory()
        // Find the specific png directly after it persists
        let url = URL(string: "https://test.com")!
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let img = createTestImage()
        cache.set(img, for: url)

        let pngUrl = try await waitForPersistedPNG(in: cacheDir)
        try Data("corrupted data".utf8).write(to: pngUrl)
        
        let newCache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let retrieved = newCache.image(for: url)
        
        #expect(retrieved == nil)
        #expect(try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil).isEmpty)
        try? FileManager.default.removeItem(at: cacheDir)
    }

    @Test func testConcurrentFetchesAreCoalesced() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let url = URL(string: "https://example.com/favicon.ico")!
        let data = try #require(createTestImage().pngData())
        let fetcher = CounterFetcher(data: data, delay: 100_000_000)
        
        let cache = FaviconCache(
            capacity: 10,
            cacheDirectory: cacheDir,
            fetchData: { urlString in
                try await fetcher.fetch(from: urlString)
            }
        )
        
        async let first = cache.fetchImage(for: url)
        async let second = cache.fetchImage(for: url)
        let firstResult = await first
        let secondResult = await second
        
        #expect(firstResult != nil)
        #expect(secondResult != nil)
        let count = await fetcher.count
        #expect(count == 1)
    }

    @Test func testDataURLDecoding() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let data = try #require(createTestImage().pngData())
        let dataURL = try #require(
            URL(string: "data:image/png;base64,\(data.base64EncodedString())")
        )
        
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let image = await cache.fetchImage(for: dataURL)
        
        #expect(image != nil)
    }

    @Test func testPlainDataURLDecoding() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let text = "Not an image, but it's plain data"
        let dataURL = try #require(URL(string: "data:text/plain,\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"))
        
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let image = await cache.fetchImage(for: dataURL)
        
        #expect(image == nil) // Fails to decode as image, but fetch should execute DataURLDecoder
    }

    @Test func testFetcherReceivesAbsoluteURLString() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let expectedURLString = "https://example.com/favicon.ico?size=64"
        let url = URL(string: expectedURLString)!
        let data = try #require(createTestImage().pngData())
        let fetcher = RecordingFetcher(data: data)
        let cache = FaviconCache(
            capacity: 10,
            cacheDirectory: cacheDir,
            fetchData: { urlString in
                try await fetcher.fetch(from: urlString)
            }
        )
        
        _ = await cache.fetchImage(for: url)
        
        let urls = await fetcher.recordedURLs()
        #expect(urls == [expectedURLString])
    }

    @Test func testUnsupportedSchemeReturnsNil() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "ftp://example.com/favicon.ico")!
        
        let image = await cache.fetchImage(for: url)
        #expect(image == nil)
    }

    @Test func testOverwriteExistingEntry() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "https://example.com/favicon.ico")!
        
        let img1 = createTestImage()
        cache.set(img1, for: url)
        
        let img2 = createTestImage()
        cache.set(img2, for: url)
        
        let retrieved = cache.image(for: url)
        #expect(retrieved != nil)
    }
}
