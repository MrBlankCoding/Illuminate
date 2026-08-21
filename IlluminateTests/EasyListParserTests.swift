//
//  EasyListParserTests.swift
//  IlluminateTests
//

import Testing
import Foundation
@testable import Illuminate

struct EasyListParserTests {

    @Test func testParseDomainBlock() throws {
        let content = "||doubleclick.net^"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect(rules[0]["trigger"]?["url-filter"] as? String == "^[^:]+:(//)?([^/]+\\.)?doubleclick\\.net[^A-Za-z0-9._%-]")
        #expect(rules[0]["action"]?["type"] as? String == "block")
    }

    @Test func testParseElementHiding() throws {
        let content = "##.ads-banner"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect(rules[0]["action"]?["selector"] as? String == ".ads-banner")
        #expect(rules[0]["action"]?["type"] as? String == "css-display-none")
    }

    @Test func testParseDomainSpecificElementHiding() throws {
        let content = "example.com##.ad-box"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect((rules[0]["trigger"]?["if-domain"] as? [String]) == ["example.com"])
        #expect(rules[0]["action"]?["selector"] as? String == ".ad-box")
        #expect(rules[0]["action"]?["type"] as? String == "css-display-none")
    }

    @Test func testParseSimpleBlock() throws {
        let content = "/ads/banner.jpg"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect(rules[0]["trigger"]?["url-filter"] as? String == "/ads/banner\\.jpg")
    }

    @Test func testParseThirdPartyOption() throws {
        let content = "||adserver.com^$third-party"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect(rules[0]["trigger"]?["url-filter"] as? String == "^[^:]+:(//)?([^/]+\\.)?adserver\\.com[^A-Za-z0-9._%-]")
        #expect((rules[0]["trigger"]?["load-type"] as? [String]) == ["third-party"])
    }

    @Test func testParseExceptionRulesAreIgnored() throws {
        let content = "@@||trusted.com^"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.isEmpty)
    }

    @Test func testUnsupportedDomainModifiersDoNotAddDomainFilters() throws {
        let content = "||bad.com^$domain=example.com|~excluded.com"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect(rules[0]["trigger"]?["url-filter"] as? String == "^[^:]+:(//)?([^/]+\\.)?bad\\.com[^A-Za-z0-9._%-]")
        #expect(rules[0]["trigger"]?["if-domain"] == nil)
        #expect(rules[0]["trigger"]?["unless-domain"] == nil)
    }

    @Test func testParseComment() throws {
        let content = "! This is a comment\n||blocked.com^"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect(rules[0]["trigger"]?["url-filter"] as? String == "^[^:]+:(//)?([^/]+\\.)?blocked\\.com[^A-Za-z0-9._%-]")
    }

    @Test func testDefaultLimitKeepsLateEasyListRules() throws {
        let skippedLines = Array(repeating: "! filler", count: 45_000).joined(separator: "\n")
        let content = skippedLines + "\n||pagead2.googlesyndication.com^"
        let rules = try decodedRules(from: EasyListParser.parse(content: content))

        #expect(rules.count == 1)
        #expect(rules[0]["trigger"]?["url-filter"] as? String == "^[^:]+:(//)?([^/]+\\.)?pagead2\\.googlesyndication\\.com[^A-Za-z0-9._%-]")
    }

    @Test func testParseAnchoredWildcardAndRegexEscapes() throws {
        let anchored = try decodedRules(from: EasyListParser.parse(content: "|ads/*banner|"))
        #expect(anchored[0]["trigger"]?["url-filter"] as? String == "^ads/.*banner$")

        let regex = try decodedRules(from: EasyListParser.parse(content: "/\\w+\\d+\\s/"))
        #expect(regex[0]["trigger"]?["url-filter"] as? String == "[A-Za-z0-9_]+[0-9]+[ \t\r\n\u{000C}]")
    }

    @Test func testParseRepetitions() throws {
        let regex = try decodedRules(from: EasyListParser.parse(content: "/[A-Za-z0-9_]{30,}\\.me\\/[A-Za-z0-9_]{30,}/"))
        #expect(regex[0]["trigger"]?["url-filter"] as? String == "[A-Za-z0-9_]+\\.me\\/[A-Za-z0-9_]+")
    }

    @Test func testParseElementHidingDomainAllowAndDenyLists() throws {
        let content = " Example.COM, ~Ads.Example.com ## .sponsored "
        let rules = try decodedRules(from: EasyListParser.parse(content: content))
        #expect(rules.count == 1)
        #expect((rules[0]["trigger"]?["if-domain"] as? [String]) == ["example.com"])
        #expect(rules[0]["trigger"]?["unless-domain"] == nil)
        #expect(rules[0]["action"]?["selector"] as? String == ".sponsored")
    }

    @Test func testParseResourceTypeInclusionsAndExclusions() throws {
        let included = try decodedRules(from: EasyListParser.parse(content: "||ads.example^$script,image"))
        #expect((included[0]["trigger"]?["resource-type"] as? [String]) == ["image", "script"])

        let excluded = try decodedRules(from: EasyListParser.parse(content: "||ads.example^$~script"))
        let excludedTypes = try #require(excluded[0]["trigger"]?["resource-type"] as? [String])
        #expect(!excludedTypes.contains("script"))
        #expect(excludedTypes.contains("image"))
    }
    private func decodedRules(from json: String) throws -> [[String: [String: Any]]] {
        let data = try #require(json.data(using: .utf8))
        let raw = try JSONSerialization.jsonObject(with: data)
        return try #require(raw as? [[String: [String: Any]]])
    }
}
