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
            
            #expect(tab.webView == nil, "WebView should be nil initially (lazy loading)")
            
            let config = WKWebViewConfiguration()
            tab.createWebViewIfNeeded(configuration: config)
            let strongWebView = tab.webView
            
            #expect(tab.webView != nil, "WebView should be created after calling createWebViewIfNeeded")
            _ = strongWebView 
        }
    }
    
    @Test func testTabSuspension() async throws {
        await MainActor.run {
            let tab = Tab(url: URL(string: "https://apple.com"), title: "Apple")
            tab.createWebViewIfNeeded(configuration: WKWebViewConfiguration())
            
            #expect(tab.webView != nil)
            tab.detachWebView()
            
            #expect(tab.webView == nil, "WebView should be released immediately")
        }
    }

    @MainActor
    @Test func testTabRestoration() async throws {
        let tab = Tab(url: URL(string: "https://apple.com"), title: "Apple")
        
        tab.isHibernated = true
        tab.detachWebView()
        
        #expect(tab.isHibernated)
        #expect(tab.webView == nil)
        
        let config = WKWebViewConfiguration()
        tab.createWebViewIfNeeded(configuration: config)
        let strongWebView = tab.webView

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(strongWebView != nil, "WebView should be strongly retained during restoration")
        #expect(tab.webView != nil, "WebView should be recreated on restoration")
        #expect(tab.isHibernated == false, "Tabs should not remain marked as hibernated after creating a web view")
    }
}
