//
//  InternalPageComponentsTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import AppKit
import SwiftUI
import Testing
@testable import Illuminate

import SwiftUI

struct InternalPageComponentsTests {
        @Test func internalPageComponentsBuildTheirBodies() {
        let page = InternalPage(icon: "star", title: "Title", accentColor: .blue) { Text("content") }
        _ = page.body
        let row = InternalPageRow { Text("row") }
        _ = row.body
        _ = InternalPageEmptyState(icon: "info", message: "Empty").body
        _ = FaviconView(image: nil).body
        _ = FaviconView(image: NSImage(size: NSSize(width: 8, height: 8))).body
    }
}
