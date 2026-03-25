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
    
    private actor CounterFetcher: FaviconDataFetching {
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
    
    private actor RecordingFetcher: FaviconDataFetching {
        var urls: [String] = []
        let data: Data
        
        init(data: Data) { self.data = data }
        
        func fetch(from urlString: String) async throws -> Data {
            urls.append(urlString)
            return data
        }
    }

    @Test func testCacheIsEmptyInitially() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "https://example.com/favicon.ico")!
        
        let retrieved = await cache.image(for: url)
        #expect(retrieved == nil)
    }

    @Test func testSetAndRetrieve() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "https://example.com/favicon.ico")!
        
        let img = createTestImage()
        await cache.set(img, for: url)
        
        let retrieved = await cache.image(for: url)
        #expect(retrieved != nil)
    }

    @Test func testLRUEvictsOldestEntry() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 8, cacheDirectory: cacheDir)
        
        let urls = (1...9).map { URL(string: "https://site\($0).com")! }
        let img = createTestImage()
        
        for url in urls.prefix(8) {
            await cache.set(img, for: url)
        }
        
        await cache.set(img, for: urls[8])
        
        let first = await cache.image(for: urls[0])
        #expect(first == nil, "Oldest element should be evicted")
        let second = await cache.image(for: urls[1])
        #expect(second != nil, "Second element should still be present")
    }

    @Test func testLRUTouchPromotesEntry() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 8, cacheDirectory: cacheDir)
        
        let urls = (1...9).map { URL(string: "https://site\($0).com")! }
        let img = createTestImage()
        
        for url in urls.prefix(8) {
            await cache.set(img, for: url)
        }
        
        // Touch first URL to make it newest
        _ = await cache.image(for: urls[0])
        
        // Add 9th URL, which should evict urls[1] instead of urls[0]
        await cache.set(img, for: urls[8])
        
        let first = await cache.image(for: urls[0])
        #expect(first != nil, "Oldest touched element should not be evicted")
        let second = await cache.image(for: urls[1])
        #expect(second == nil, "Second element should be evicted instead")
    }

    @Test func testDiskPersistenceAcrossInstances() async throws {
        let cacheDir = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let url = URL(string: "https://persist-test.com")!
        
        let img = createTestImage()
        await cache.set(img, for: url)
        
        let newCache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let retrieved = await newCache.image(for: url)
        
        #expect(retrieved != nil)
    }

    @Test func testCorruptDiskDataIsCleanedUp() async throws {
        let cacheDir = temporaryCacheDirectory()
        // Find the specific png directly after it persists
        let url = URL(string: "https://test.com")!
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let img = createTestImage()
        await cache.set(img, for: url)
        
        let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        let pngUrl = try #require(files?.first { $0.pathExtension == "png" })
        try Data("corrupted data".utf8).write(to: pngUrl)
        
        let newCache = FaviconCache(capacity: 10, cacheDirectory: cacheDir)
        let retrieved = await newCache.image(for: url)
        
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
        
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir, fetcher: fetcher)
        
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
        let cache = FaviconCache(capacity: 10, cacheDirectory: cacheDir, fetcher: fetcher)
        
        _ = await cache.fetchImage(for: url)
        
        let urls = await fetcher.urls
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
        await cache.set(img1, for: url)
        
        let img2 = createTestImage()
        await cache.set(img2, for: url)
        
        let retrieved = await cache.image(for: url)
        #expect(retrieved != nil)
    }
}
