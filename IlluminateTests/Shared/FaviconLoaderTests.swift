//
//  AppDelegate.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import AppKit
import Foundation
import Testing
import Nuke
@testable import Illuminate

struct FaviconLoaderTests {
    @Test func defaultFaviconURLIsCorrect() {
        let page = URL(string: "https://example.com/some/page?q=1")!
        let favicon = FaviconLoader.defaultFaviconURL(for: page)
        #expect(favicon?.absoluteString == "https://example.com/favicon.ico")
        #expect(FaviconLoader.defaultFaviconURL(for: nil) == nil)
        #expect(FaviconLoader.defaultFaviconURL(for: URL(string: "file:///tmp/index.html")!) == nil)
    }

    @Test func resolveFaviconURLHandlesRelativeAndAbsolute() {
        let page = URL(string: "https://example.com/blog/post")!
        #expect(FaviconLoader.resolveFaviconURL(from: "/icon.png", pageURL: page)?.absoluteString == "https://example.com/icon.png")
        #expect(FaviconLoader.resolveFaviconURL(from: "https://cdn.example.com/fav.ico", pageURL: page)?.absoluteString == "https://cdn.example.com/fav.ico")
        #expect(FaviconLoader.resolveFaviconURL(from: "   ", pageURL: page) == nil)
        #expect(FaviconLoader.resolveFaviconURL(from: "data:image/png;base64,abcd", pageURL: page)?.scheme == "data")
        #expect(FaviconLoader.resolveFaviconURL(from: "ftp://example.com/icon.ico", pageURL: page) == nil)
    }

    @Test func dataFaviconLoadsWithoutNetwork() async {
        let loader = FaviconLoader()
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()
        guard let png = image.pngData() else { return }
        let b64 = png.base64EncodedString()
        let url = URL(string: "data:image/png;base64,\(b64)")!
        let result = await loader.loadFavicon(from: url)
        #expect(result != nil)
    }

    @Test func unsupportedSchemeReturnsNil() async {
        let loader = FaviconLoader()
        let url = URL(string: "ftp://example.com/favicon.ico")!
        let result = await loader.loadFavicon(from: url)
        #expect(result == nil)
    }

    @Test func negativeCachePreventsRepeatedFailures() async {
        let loader = FaviconLoader()
        let url = URL(string: "https://127.0.0.1:1/favicon.ico")!
        let first = await loader.loadFavicon(from: url)
        #expect(first == nil)
        let start = CFAbsoluteTimeGetCurrent()
        let second = await loader.loadFavicon(from: url)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        #expect(second == nil)
        #expect(elapsed < 0.2)
    }

    @Test func faviconCacheStillEvictsLRU() {
        let cache = FaviconCache(capacity: 4)
        let urls = (0..<5).map { URL(string: "https://site\($0).example/favicon.ico")! }
        for url in urls {
            cache.performInline_set(NSImage(size: NSSize(width: 8, height: 8)), for: url)
        }

        #expect(cache.image(for: urls[0]) == nil)
        #expect(cache.image(for: urls[4]) != nil)
    }

    @Test func pipelineConfigurationIsReasonable() {
        let pipeline = BrowserImagePipeline.shared
        #expect((pipeline.configuration.imageCache as? ImageCache)?.costLimit == 64 * 1024 * 1024)
        #expect(pipeline.configuration.dataCache != nil)
        #expect(pipeline.configuration.isTaskCoalescingEnabled == true)
    }
}
