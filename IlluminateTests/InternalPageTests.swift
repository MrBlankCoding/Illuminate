//
//  InternalPageTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import AppKit
import SwiftUI
import Testing
@testable import Illuminate

struct InternalPageTests {
    @Test func internalPageComponentsBuildTheirBodies() {
        let page = InternalPage(icon: "star", title: "Title", accentColor: .blue) { Text("content") }
        _ = page.body
        let row = InternalPageRow { Text("row") }
        _ = row.body
        _ = InternalPageEmptyState(icon: "info", message: "Empty").body
        _ = FaviconView(image: nil).body
        _ = FaviconView(image: NSImage(size: NSSize(width: 8, height: 8))).body
    }

    @Test func illuminateInfoPageRoutesCorrectly() {
        let url = URL(string: "illuminate://info")!
        let page = IlluminatePage(url: url)
        #expect(page == .info)
        #expect(page?.url == url)
    }
}
