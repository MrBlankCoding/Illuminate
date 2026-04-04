//
//  TabLifecycleTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/9/26.
//

import Testing
import WebKit
import Foundation
@testable import Illuminate

struct TabLifecycleTests {

    @Test func testLazyWebViewCreation() async throws {
        await MainActor.run {
            let tab = Tab(url: URL(string: "https://apple.com"), title: "Apple")
            let webKitManager = WebKitManager(profile: BrowserProfile(name: "Test Profile"))
            
            #expect(tab.webView == nil, "WebView should be nil initially (lazy loading)")
            
            let config = WKWebViewConfiguration()
            tab.createWebViewIfNeeded(configuration: config, webKitManager: webKitManager)
            let strongWebView = tab.webView
            
            #expect(tab.webView != nil, "WebView should be created after calling createWebViewIfNeeded")
            _ = strongWebView 
        }
    }
    
    @Test func testTabSuspension() async throws {
        await MainActor.run {
            let tab = Tab(url: URL(string: "https://apple.com"), title: "Apple")
            let webKitManager = WebKitManager(profile: BrowserProfile(name: "Test Profile"))
            tab.createWebViewIfNeeded(
                configuration: WKWebViewConfiguration(),
                webKitManager: webKitManager
            )
            
            #expect(tab.webView != nil)
            tab.detachWebView()
            
            #expect(tab.webView == nil, "WebView should be released immediately")
        }
    }

    @MainActor
    @Test func testTabRestoration() async throws {
        let tab = Tab(url: URL(string: "https://apple.com"), title: "Apple")
        let webKitManager = WebKitManager(profile: BrowserProfile(name: "Test Profile"))
        
        tab.isHibernated = true
        tab.detachWebView()
        
        #expect(tab.isHibernated)
        #expect(tab.webView == nil)
        
        let config = WKWebViewConfiguration()
        tab.createWebViewIfNeeded(configuration: config, webKitManager: webKitManager)
        let strongWebView = tab.webView

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(strongWebView != nil, "WebView should be strongly retained during restoration")
        #expect(tab.webView != nil, "WebView should be recreated on restoration")
        #expect(tab.isHibernated == false, "Tabs should not remain marked as hibernated after creating a web view")
    }

    @MainActor
    @Test func testClosingTabDetachesWebViewImmediately() async throws {
        let manager = TabManager(isPersistenceEnabled: false)
        let webKitManager = WebKitManager(profile: BrowserProfile(name: "Test Profile"), isPersistenceEnabled: false)
        let tab = manager.createTab(url: URL(string: "https://apple.com"))

        tab.createWebViewIfNeeded(
            configuration: WKWebViewConfiguration(),
            webKitManager: webKitManager
        )

        #expect(tab.webView != nil)

        manager.closeTab(id: tab.id)

        #expect(tab.webView == nil, "Closing a tab should tear down its web view immediately")
        #expect(manager.tabs.contains(where: { $0.id == tab.id }) == false)
    }

    @MainActor
    @Test func testAttachingWebViewOwnedByAnotherTabThrowsConflict() async throws {
        let webKitManager = WebKitManager(profile: BrowserProfile(name: "Test Profile"), isPersistenceEnabled: false)
        let firstTab = Tab(url: URL(string: "https://one.example"), title: "One")
        let secondTab = Tab(url: URL(string: "https://two.example"), title: "Two")

        firstTab.createWebViewIfNeeded(
            configuration: WKWebViewConfiguration(),
            webKitManager: webKitManager
        )

        let firstWebView = try #require(firstTab.webView)

        #expect(throws: TabError.webViewOwnershipConflict) {
            try secondTab.attachWebView(firstWebView)
        }
    }

    @MainActor
    @Test func testTransferPayloadPreservesTabIdentityAndRoutingState() async throws {
        let groupID = UUID()
        let tab = Tab(
            id: UUID(),
            url: URL(string: "https://example.com/path"),
            title: "Example",
            groupID: groupID
        )

        let payload = tab.toTransferPayload()

        #expect(payload.id == tab.id)
        #expect(payload.url == tab.url)
        #expect(payload.title == "Example")
        #expect(payload.groupID == groupID)
    }
}
