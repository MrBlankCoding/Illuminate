//
//  SearchEngineTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
@testable import Illuminate

struct SearchEngineTests {
    @Test func googleSearchURLIncludesExpectedQueryParam() {
        let url = SearchEngine.google.searchURL(for: "hello world")

        #expect(url != nil)
        #expect(url?.host == "www.google.com")
        #expect(url?.query?.contains("q=") == true)
        #expect(url?.query?.contains("hello") == true)
    }

    @Test func bingSearchURLUsesBingEndpoint() {
        let url = SearchEngine.bing.searchURL(for: "browser")

        #expect(url != nil)
        #expect(url?.host == "www.bing.com")
        #expect(url?.query == "q=browser")
    }

    @Test func duckDuckGoSuggestionURLEscapesQueryText() {
        let url = SearchEngine.duckDuckGo.suggestionURL(for: "two words")

        #expect(url != nil)
        #expect(url?.absoluteString.hasPrefix("https://duckduckgo.com/ac/?q=") == true)
        #expect(url?.absoluteString.contains("two%20words") == true)
    }
}
