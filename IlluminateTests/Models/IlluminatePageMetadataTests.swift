//
//  IlluminatePageMetadataTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct IlluminatePageMetadataTests {

    @Test func everySuggestiblePageHasConsistentMetadata() {
        for page in IlluminatePage.suggestiblePages {
            #expect(!page.title.isEmpty)
            #expect(!page.tabTitle.isEmpty)
            #expect(!page.icon.isEmpty)
            #expect(!page.keywords.isEmpty)
            #expect(page.url.absoluteString == "illuminate://\(page.rawValue)")
        }
    }

    @Test func suggestiblePagesExcludeBarePdfViewer() {
        // The PDF viewer requires a `src` parameter, so the bare page
        // must never appear in address-bar suggestions.
        #expect(!IlluminatePage.suggestiblePages.contains(.pdf))
        #expect(IlluminatePage.allCases.contains(.pdf))
        #expect(IlluminatePage.suggestiblePages.count == IlluminatePage.allCases.count - 1)
    }

    @Test func tabTitlesMatchExpectations() {
        #expect(IlluminatePage.passwords.tabTitle == "Passwords")
        #expect(IlluminatePage.protection.tabTitle == "Protection")
        #expect(IlluminatePage.downloads.tabTitle == "Downloads")
        #expect(IlluminatePage.history.tabTitle == "History")
        #expect(IlluminatePage.permissions.tabTitle == "Permissions")
        #expect(IlluminatePage.info.tabTitle == "Browser Info")
        #expect(IlluminatePage.extensions.tabTitle == "Extensions")
    }

    @Test func keywordsSupportSearchTerms() {
        #expect(IlluminatePage.passwords.keywords.contains("logins"))
        #expect(IlluminatePage.history.keywords.contains("visited"))
        #expect(IlluminatePage.extensions.keywords.contains("addons"))
    }

    @Test func displayTitleFallsBackToURLHostForEmptyTitle() {
        let url = URL(string: "illuminate://info")!
        // Non-PDF pages use their tab title.
        #expect(IlluminatePage.info.displayTitle(for: url) == IlluminatePage.info.tabTitle)
    }
}
