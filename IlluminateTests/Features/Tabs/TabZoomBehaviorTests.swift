//
//  TabZoomBehaviorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
import WebKit
@testable import Illuminate

@MainActor
struct TabZoomBehaviorTests {
    private func makeTab() -> Tab {
        let tab = Tab(url: URL(string: "https://example.com"), title: "Example")
        let extensionManager = ExtensionManager(profileID: nil, isGuestSession: true)
        let webKitManager = WebKitManager(
            profile: BrowserProfile(name: "Zoom Test"),
            isPersistenceEnabled: false,
            extensionManager: extensionManager
        )
        tab.createWebViewIfNeeded(
            configuration: WKWebViewConfiguration(),
            webKitManager: webKitManager
        )
        return tab
    }

    @Test func zoomInAndOutChangeTheWebViewAndTabLevelTogether() throws {
        let tab = makeTab()
        let webView = try #require(tab.webView)

        tab.zoomIn()
        #expect(webView.pageZoom == 1.1)
        #expect(tab.zoomLevel == 1.1)

        tab.zoomOut()
        #expect(webView.pageZoom == 1.0)
        #expect(tab.zoomLevel == 1.0)
    }

    @Test func zoomLevelsAreClampedToSupportedBounds() throws {
        let tab = makeTab()
        let webView = try #require(tab.webView)

        webView.pageZoom = 5.0
        tab.zoomIn()
        #expect(tab.zoomLevel == Tab.ZoomBounds.max)

        webView.pageZoom = 0.25
        tab.zoomOut()
        #expect(tab.zoomLevel == Tab.ZoomBounds.min)
    }

    @Test func resetZoomReturnsToDefaultLevel() throws {
        let tab = makeTab()
        let webView = try #require(tab.webView)
        webView.pageZoom = 2.0

        tab.resetZoom()

        #expect(webView.pageZoom == Tab.ZoomBounds.default)
        #expect(tab.zoomLevel == Tab.ZoomBounds.default)
    }
}
