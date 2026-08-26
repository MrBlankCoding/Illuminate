//
//  BookmarkTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Testing
@testable import Illuminate

struct BookmarkTests {
    @Test func initializerStoresMetadata() {
        let profileID = UUID()
        let bookmarkID = UUID()
        let bookmark = Bookmark(id: bookmarkID, profileID: profileID, title: "Illuminate", url: "https://example.com")
        #expect(bookmark.id == bookmarkID)
        #expect(bookmark.profileID == profileID)
        #expect(bookmark.title == "Illuminate")
        #expect(bookmark.url == "https://example.com")
    }
}
