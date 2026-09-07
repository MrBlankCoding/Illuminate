//
//  FaviconSchemeTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
@testable import Illuminate

struct FaviconSchemeTests {

    @Test("isSupportedScheme rejects non-HTTP schemes")
    func isSupportedSchemeRejectsNonHTTP() {
        let unsupported = [
            URL(string: "file:///favicon.ico")!,
            URL(string: "about:blank")!,
            URL(string: "blob:https://example.com/uuid")!,
        ]
        for url in unsupported {
            #expect(FaviconLoader.isSupportedScheme(url) == false)
        }
    }

    @Test("isSupportedScheme accepts http/https/data")
    func isSupportedSchemeAcceptsHTTP() {
        let supported = [
            URL(string: "http://example.com/favicon.ico")!,
            URL(string: "https://example.com/favicon.ico")!,
            URL(string: "data:image/png;base64,abc")!,
        ]
        for url in supported {
            #expect(FaviconLoader.isSupportedScheme(url) == true)
        }
    }

    @Test("defaultFaviconURL returns nil for unsupported schemes")
    func defaultFaviconURLRejectsUnsupported() {
        let unsupported = [
            URL(string: "file:///etc/hosts")!,
            URL(string: "about:blank")!,
            URL(string: "data:text/plain,hello")!,
            URL(string: "blob:https://example.com/uuid")!,
        ]
        for url in unsupported {
            #expect(FaviconLoader.defaultFaviconURL(for: url) == nil)
        }
    }

    @Test("defaultFaviconURL builds correct URLs for supported schemes")
    func defaultFaviconURLBuildsForSupported() {
        let cases: [(String, String)] = [
            ("http://example.com/a/b", "http://example.com/favicon.ico"),
            ("https://example.com/a/b", "https://example.com/favicon.ico"),
            ("https://sub.example.com/x", "https://sub.example.com/favicon.ico"),
            ("webkit-extension://my-ext/page", "webkit-extension://my-ext/favicon.ico"),
        ]
        for (input, expected) in cases {
            let url = URL(string: input)!
            #expect(FaviconLoader.defaultFaviconURL(for: url)?.absoluteString == expected)
        }
    }

    @Test("resolveFaviconURL rejects unsupported scheme results")
    func resolveFaviconURLRejectsUnsupported() {
        let pageURL = URL(string: "https://example.com")!
        let rejected: [String] = [
            "file:///etc/hosts",
            "about:blank",
            "javascript:alert(1)",
        ]
        for raw in rejected {
            #expect(FaviconLoader.resolveFaviconURL(from: raw, pageURL: pageURL) == nil)
        }
    }

    @Test("resolveFaviconURL resolves relative URLs against pageURL")
    func resolveFaviconURLRelative() {
        let pageURL = URL(string: "https://example.com/path/")!
        let result = FaviconLoader.resolveFaviconURL(from: "icons/favicon.png", pageURL: pageURL)
        #expect(result?.absoluteString == "https://example.com/path/icons/favicon.png")
    }

    @Test("resolveFaviconURL with relative base resolves to parent path")
    func resolveFaviconURLRelativeWithoutTrailingSlash() {
        let pageURL = URL(string: "https://example.com/path/page.html")!
        let result = FaviconLoader.resolveFaviconURL(from: "icons/favicon.png", pageURL: pageURL)
        #expect(result?.absoluteString == "https://example.com/path/icons/favicon.png")
    }

    @Test("data URL favicon is resolved by resolveFaviconURL")
    func resolveFaviconDataURL() {
        let pageURL = URL(string: "https://example.com")!
        let dataURL = "data:image/png;base64,iVBORw0KGgo="
        let result = FaviconLoader.resolveFaviconURL(from: dataURL, pageURL: pageURL)
        #expect(result?.absoluteString == dataURL)
    }
}
