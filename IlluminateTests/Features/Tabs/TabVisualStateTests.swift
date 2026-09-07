//
//  TabVisualStateTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import AppKit
import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabVisualStateTests {

    private func makeTabManager() -> TabManager {
        TabManager(
            profile: BrowserProfile(name: "Test"),
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: false
        )
    }

    @Test("defaultFaviconURL returns /favicon.ico for http hosts")
    func defaultFaviconForHTTP() {
        let tm = makeTabManager()
        let url = URL(string: "http://example.com/some/page")!
        let favicon = tm.defaultFaviconURL(for: url)
        #expect(favicon?.absoluteString == "http://example.com/favicon.ico")
    }

    @Test("defaultFaviconURL returns /favicon.ico for https hosts")
    func defaultFaviconForHTTPS() {
        let tm = makeTabManager()
        let url = URL(string: "https://example.com/path")!
        let favicon = tm.defaultFaviconURL(for: url)
        #expect(favicon?.absoluteString == "https://example.com/favicon.ico")
    }

    @Test("defaultFaviconURL builds extension favicon URL using host as extension ID")
    func defaultFaviconForExtension() {
        let tm = makeTabManager()
        let url = URL(string: "webkit-extension://abcdef-uuid/page")!
        let favicon = tm.defaultFaviconURL(for: url)
        #expect(favicon?.absoluteString == "webkit-extension://abcdef-uuid/favicon.ico")
    }

    @Test("defaultFaviconURL returns nil for non-http(s)/extension schemes")
    func defaultFaviconNilForOtherSchemes() {
        let tm = makeTabManager()
        let cases: [String] = [
            "illuminate://passwords",
            "file:///etc/hosts",
            "about:blank",
            "data:text/plain,hello",
        ]
        for raw in cases {
            let url = URL(string: raw)!
            #expect(tm.defaultFaviconURL(for: url) == nil, "Expected nil for \(raw)")
        }
    }

    @Test("defaultFaviconURL returns nil for nil URL")
    func defaultFaviconNilForNilURL() {
        let tm = makeTabManager()
        #expect(tm.defaultFaviconURL(for: nil) == nil)
    }

    @Test("specialFavicon returns SF Symbol for known illuminate pages")
    func specialFaviconForKnownPages() {
        let tm = makeTabManager()
        let cases: [String] = [
            "illuminate://passwords",
            "illuminate://protection",
            "illuminate://downloads",
            "illuminate://history",
        ]
        for raw in cases {
            let url = URL(string: raw)!
            #expect(tm.specialFavicon(for: url) != nil, "Expected icon for \(raw)")
        }
    }

    @Test("specialFavicon returns nil for unknown illuminate pages")
    func specialFaviconForUnknownPages() {
        let tm = makeTabManager()
        let url = URL(string: "illuminate://unknown-page")!
        #expect(tm.specialFavicon(for: url) == nil)
    }

    @Test("specialFavicon returns nil for non-illuminate schemes")
    func specialFaviconForOtherSchemes() {
        let tm = makeTabManager()
        let cases: [String] = [
            "https://example.com",
            "file:///x",
            "webkit-extension://abcdef/page",
        ]
        for raw in cases {
            let url = URL(string: raw)!
            #expect(tm.specialFavicon(for: url) == nil, "Expected nil for \(raw)")
        }
    }

    @Test("specialFavicon returns nil for nil URL")
    func specialFaviconForNilURL() {
        let tm = makeTabManager()
        #expect(tm.specialFavicon(for: nil) == nil)
    }
}
