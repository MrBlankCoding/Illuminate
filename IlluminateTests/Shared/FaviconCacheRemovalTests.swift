//
//  FaviconCacheRemovalTests.swift
//  IlluminateTests
//
//  Tests for FaviconCache.removeAll(matchingScheme:host:) — used during
//  extension uninstall to purge cached favicon entries. Guards against
//  regressions where stale favicons remain after an extension is removed.
//

import Foundation
import Testing
import AppKit
@testable import Illuminate

struct FaviconCacheRemovalTests {

    private func makeCache() -> FaviconCache {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaviconCacheTest-\(UUID().uuidString)", isDirectory: true)
        return FaviconCache(capacity: 10, cacheDirectory: tempDir)
    }

    private func makeImage() -> NSImage {
        NSImage(systemSymbolName: "globe", accessibilityDescription: nil)!
    }

    @Test("removeAll purges in-memory entries matching scheme and host")
    func removeAllPurgedInMemory() {
        let cache = makeCache()
        let key = URL(string: "webkit-extension://my-ext/icon.png")!
        cache.performInline_set(makeImage(), for: key)

        #expect(cache.memoryImage(for: key) != nil)

        cache.removeAll(matchingScheme: "webkit-extension", host: "my-ext")

        #expect(cache.memoryImage(for: key) == nil)
    }

    @Test("removeAll leaves entries for other extensions intact")
    func removeAllLeavesOthers() {
        let cache = makeCache()
        let a = URL(string: "webkit-extension://ext-a/icon.png")!
        let b = URL(string: "webkit-extension://ext-b/icon.png")!
        cache.performInline_set(makeImage(), for: a)
        cache.performInline_set(makeImage(), for: b)

        cache.removeAll(matchingScheme: "webkit-extension", host: "ext-a")

        #expect(cache.memoryImage(for: a) == nil)
        #expect(cache.memoryImage(for: b) != nil)
    }

    @Test("removeAll leaves entries on other schemes intact")
    func removeAllLeavesOtherSchemes() {
        let cache = makeCache()
        let ext = URL(string: "webkit-extension://my-ext/icon.png")!
        let web = URL(string: "https://example.com/favicon.ico")!
        cache.performInline_set(makeImage(), for: ext)
        cache.performInline_set(makeImage(), for: web)

        cache.removeAll(matchingScheme: "webkit-extension", host: "my-ext")

        #expect(cache.memoryImage(for: ext) == nil)
        #expect(cache.memoryImage(for: web) != nil)
    }

    @Test("removeAll is a no-op for unrelated host")
    func removeAllNoMatch() {
        let cache = makeCache()
        let key = URL(string: "webkit-extension://my-ext/icon.png")!
        cache.performInline_set(makeImage(), for: key)

        cache.removeAll(matchingScheme: "webkit-extension", host: "other-ext")

        #expect(cache.memoryImage(for: key) != nil)
    }

    @Test("removeAll is a no-op on empty cache")
    func removeAllEmptyNoCrash() {
        let cache = makeCache()
        cache.removeAll(matchingScheme: "webkit-extension", host: "my-ext")
        // should not crash
    }

    @Test("removeAll is case-insensitive on scheme")
    func removeAllCaseInsensitiveScheme() {
        let cache = makeCache()
        let key = URL(string: "WEBKIT-EXTENSION://My-Ext/icon.png")!
        cache.performInline_set(makeImage(), for: key)

        cache.removeAll(matchingScheme: "webkit-extension", host: "My-Ext")

        #expect(cache.memoryImage(for: key) == nil)
    }
}
