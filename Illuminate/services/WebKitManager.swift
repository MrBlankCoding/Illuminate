//
//  WebKitManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation
import WebKit
import Combine

@MainActor
final class WebKitManager: ObservableObject {

    static let shared = WebKitManager()

    @Published var cookiesEnabled: Bool = true

    private init() {
        URLCache.shared.memoryCapacity = 100 * 1024 * 1024 // Increase to 100MB
        URLCache.shared.diskCapacity = 500 * 1024 * 1024 // 500MB disk cache
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        configuration.mediaTypesRequiringUserActionForPlayback = []

        configuration.websiteDataStore = cookiesEnabled
            ? .default()
            : .nonPersistent()

        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        let preferences = WKPreferences()
        preferences.isTextInteractionEnabled = true
        preferences.isElementFullscreenEnabled = true

        configuration.preferences = preferences
        configuration.userContentController = WKUserContentController()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if let ruleList = AdBlockService.shared.contentRuleList {
            configuration.userContentController.add(ruleList)
        }

        return configuration
    }

    func makeWebView() -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        applySafariUserAgent(to: webView)
        return webView
    }
    // i supposed UA needs to be updated in the future but for now this will work
    // also appending Illuminate/1.0 to the end of the UA so that websites can detect that we're using Illuminate and potentially serve a custom experience in the future :p
    func applySafariUserAgent(to webView: WKWebView) {
        let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.3.1 Safari/605.1.15 Chrome/122.0.0.0 Illuminate/1.0"
        webView.customUserAgent = safariUA
        AppLog.info("Set custom UA: \(safariUA)")
    }
}
