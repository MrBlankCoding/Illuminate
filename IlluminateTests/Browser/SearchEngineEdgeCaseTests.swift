//
//  SearchEngineEdgeCaseTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
@testable import Illuminate

struct SearchEngineEdgeCaseTests {

    @Test("google encodes a simple query")
    func googleSimpleQuery() throws {
        let url = try #require(SearchEngine.google.searchURL(for: "hello"))
        #expect(url.absoluteString.contains("q=hello"))
    }

    @Test("duckduckgo encodes a simple query")
    func duckduckgoSimpleQuery() throws {
        let url = try #require(SearchEngine.duckDuckGo.searchURL(for: "hello"))
        #expect(url.absoluteString.contains("q=hello"))
    }

    @Test("bing encodes a simple query")
    func bingSimpleQuery() throws {
        let url = try #require(SearchEngine.bing.searchURL(for: "hello"))
        #expect(url.absoluteString.contains("q=hello"))
    }

    @Test("whitespace in query is percent-encoded")
    func whitespaceEncoded() throws {
        let url = try #require(SearchEngine.google.searchURL(for: "hello world"))
        #expect(url.absoluteString.contains("hello%20world") || url.absoluteString.contains("hello+world"))
    }

    @Test("special characters are percent-encoded")
    func specialCharactersEncoded() throws {
        let url = try #require(SearchEngine.google.searchURL(for: "a&b=c"))
        #expect(url.absoluteString.contains("a%26b%3Dc") || url.absoluteString.contains("a%26b=c"))
    }

    @Test("all engines use the q parameter")
    func queryParameterIsQ() {
        for engine in SearchEngine.allCases {
            #expect(engine.queryParameterName == "q", "Engine \(engine) should use 'q'")
        }
    }

    @Test("searchURL returns a non-nil URL for any non-empty query")
    func searchURLNonNilForAll() {
        for engine in SearchEngine.allCases {
            #expect(engine.searchURL(for: "x") != nil)
        }
    }

    @Test("suggestionURL encodes the query")
    func suggestionURLEncodes() throws {
        let url = try #require(SearchEngine.google.suggestionURL(for: "hello world"))
        #expect(url.absoluteString.contains("hello%20world"))
    }

    @Test("suggestionURL for empty query does not crash")
    func suggestionURLEmpty() {
        for engine in SearchEngine.allCases {
            _ = engine.suggestionURL(for: "")
        }
    }
}
