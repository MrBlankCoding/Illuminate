//
//  AppLogTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
@testable import Illuminate

struct AppLogTests {

    @Test("nil URL serializes as <nil>")
    func nilURL() {
        #expect(AppLog.sanitizedURL(nil) == "<nil>")
    }

    @Test("URL without query is preserved verbatim")
    func noQueryPreserved() {
        let url = URL(string: "https://example.com/path")!
        #expect(AppLog.sanitizedURL(url) == "https://example.com/path")
    }

    @Test("URL with query has query items replaced with a single redacted marker")
    func queryRedacted() {
        let url = URL(string: "https://example.com/path?token=abc123&secret=shhh")!
        let result = AppLog.sanitizedURL(url)
        #expect(result.contains("example.com"))
        #expect(result.contains("redacted"))
        #expect(!result.contains("abc123"))
        #expect(!result.contains("shhh"))
    }

    @Test("scheme is preserved on redacted URL")
    func schemePreserved() {
        let url = URL(string: "https://example.com/?secret=x")!
        let result = AppLog.sanitizedURL(url)
        #expect(result.hasPrefix("https://"))
    }

    @Test("empty query string does not add a redacted marker")
    func emptyQueryNotRedacted() {
        let url = URL(string: "https://example.com/path")!
        let result = AppLog.sanitizedURL(url)
        #expect(!result.contains("redacted"))
    }

    @Test("URL with only fragment is not redacted")
    func fragmentNotRedacted() {
        let url = URL(string: "https://example.com/page#section")!
        let result = AppLog.sanitizedURL(url)
        #expect(result.contains("section"))
        #expect(!result.contains("redacted"))
    }
}
