//
//  WebViewRepresentable.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
    @ObservedObject var tab: Tab
    @ObservedObject var adBlockService: AdBlockService = .shared
    let tabManager: TabManager
    let userInterfaceStyle: TabManager.UIStyle

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tab: tab,
            tabManager: tabManager,
            webScriptBridge: WebScriptBridge.shared,
            adBlockService: adBlockService,
            dohService: DNSOverHTTPSService.shared,
            safeBrowsing: SafeBrowsingManager.shared,
            faviconCache: FaviconCache.shared
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        tab.createWebViewIfNeeded(configuration: WebKitManager.shared.makeConfiguration())
        
        guard let webView = tab.webView else {
            let fallback = WebKitManager.shared.makeWebView()
            return fallback
        }
        
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = tab.id == tabManager.activeTabID
        WebScriptBridge.shared.installScripts(on: webView.configuration.userContentController, handler: context.coordinator)
        
        context.coordinator.applyContentRules(to: webView, ruleList: adBlockService.contentRuleList)
        context.coordinator.applyWebAppearance(to: webView, style: userInterfaceStyle)

        if tab.isHibernated {
            context.coordinator.restoreHibernatedStateIfNeeded(into: webView)
        } else if let url = tab.url, webView.url == nil {
            webView.load(makeRequest(for: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.allowsBackForwardNavigationGestures = tab.id == tabManager.activeTabID
        
        context.coordinator.applyContentRules(to: nsView, ruleList: adBlockService.contentRuleList)

        if tab.isHibernated {
            context.coordinator.restoreHibernatedStateIfNeeded(into: nsView)
        }

        context.coordinator.applyWebAppearance(to: nsView, style: userInterfaceStyle)
    }

    private func shouldLoad(_ targetURL: URL, in webView: WKWebView) -> Bool {
        return false
    }

    private func areEquivalentURLs(_ lhs: URL, _ rhs: URL) -> Bool {
        canonicalURLString(lhs) == canonicalURLString(rhs)
    }

    private func makeRequest(for url: URL) -> URLRequest {
        if url.scheme == "illuminate" {
            return URLRequest(url: URL(string: "about:blank")!)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        return request
    }

    private func canonicalURLString(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            var s = url.absoluteString.lowercased()
            if s.hasSuffix("/") { s.removeLast() }
            return s
        }

        components.fragment = nil
        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path.removeLast()
        } else if components.path == "/" {
            components.path = ""
        }

        var s = (components.string ?? url.absoluteString).lowercased()
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
