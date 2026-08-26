//
//  FaviconCacheTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import AppKit
import Foundation
import Testing
@testable import Illuminate

struct FaviconCacheTests {
    @Test func inlineImagesAreCachedAndEvicted() {
        let cache = FaviconCache(capacity: 8)
        let firstURL = URL(string: "https://one.example/icon")!
        cache.performInline_set(NSImage(size: NSSize(width: 8, height: 8)), for: firstURL)
        #expect(cache.image(for: firstURL) != nil)
        for index in 1...8 {
            let url = URL(string: "https://\(index).example/icon")!
            cache.performInline_set(NSImage(size: NSSize(width: 8, height: 8)), for: url)
        }
        #expect(cache.image(for: firstURL) == nil)
    }

    @Test func invalidAndUnsupportedFetchesReturnNil() async {
        let cache = FaviconCache(capacity: 8)
        #expect(await cache.fetchImage(for: URL(string: "ftp://example.com/icon")!) == nil)
        #expect(await cache.fetchImage(for: URL(string: "data:image/png;base64,not-valid")!) == nil)
    }
}
