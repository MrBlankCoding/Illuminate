//
//  IlluminatePageTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
@testable import Illuminate

struct IlluminatePageTests {

    @Test("every case maps to a known host")
    func roundTripURL() {
        for page in IlluminatePage.allCases {
            let url = page.url
            let parsed = IlluminatePage(url: url)
            #expect(parsed == page, "Round-trip failed for \(page.rawValue)")
        }
    }

    @Test("non-illuminate URLs do not produce a page")
    func nonIlluminateURLs() {
        let cases = [
            "https://example.com",
            "http://example.com",
            "file:///x",
            "about:blank",
            "webkit-extension://abc/page",
            "data:text/plain,hello",
        ]
        for raw in cases {
            let url = URL(string: raw)!
            #expect(IlluminatePage(url: url) == nil, "Expected nil for \(raw)")
        }
    }

    @Test("unknown illuminate host does not produce a page")
    func unknownIlluminateHost() {
        let url = URL(string: "illuminate://does-not-exist")!
        #expect(IlluminatePage(url: url) == nil)
    }

    @Test("host comparison is case insensitive")
    func caseInsensitiveHost() {
        let upperURL = URL(string: "illuminate://PASSWORDs")!
        let lowerURL = URL(string: "illuminate://passwords")!
        #expect(IlluminatePage(url: upperURL) == .passwords)
        #expect(IlluminatePage(url: lowerURL) == .passwords)
    }

    @Test("scheme comparison is case insensitive")
    func caseInsensitiveScheme() {
        let url = URL(string: "ILLUMINATE://history")!
        #expect(IlluminatePage(url: url) == .history)
    }

    @Test("every page has unique title and tabTitle")
    func uniqueTitles() {
        let pages = IlluminatePage.allCases
        #expect(Set(pages.map(\.title)).count == pages.count)
        #expect(Set(pages.map(\.tabTitle)).count == pages.count)
    }

    @Test("every page has unique icon")
    func uniqueIcons() {
        let pages = IlluminatePage.allCases
        #expect(Set(pages.map(\.icon)).count == pages.count)
    }

    @Test("every page has keywords")
    func keywordsNotEmpty() {
        for page in IlluminatePage.allCases {
            #expect(!page.keywords.isEmpty, "Page \(page.rawValue) has no keywords")
        }
    }

    @Test("suggestiblePages returns all cases")
    func suggestiblePagesAll() {
        #expect(IlluminatePage.suggestiblePages.count == IlluminatePage.allCases.count)
    }
}
