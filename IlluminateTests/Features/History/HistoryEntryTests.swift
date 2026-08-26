//
//  HistoryEntryTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Testing
@testable import Illuminate

struct HistoryEntryTests {
    @Test func derivedURLsAndDisplayTitles() {
        let titled = HistoryEntry(urlString: "https://example.com/path", title: "Example", faviconURLString: "https://example.com/icon")
        #expect(titled.url?.host == "example.com")
        #expect(titled.faviconURL != nil)
        #expect(titled.displayTitle == "Example")
        let fallback = HistoryEntry(urlString: "https://fallback.example/path", title: "")
        #expect(fallback.displayTitle == "fallback.example")
        #expect(fallback.faviconURL == nil)
    }
}
