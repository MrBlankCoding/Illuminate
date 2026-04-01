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

    @Published var cookiesEnabled: Bool = true {
        didSet {
            guard !isLoadingProfile else { return }
            userDefaults.set(cookiesEnabled, forKey: scopedKey("cookiesEnabled"))
        }
    }

    private let userDefaults: UserDefaults
    private var activeProfileID: UUID?
    private var isLoadingProfile = false

    init(profile: BrowserProfile, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.activeProfileID = profile.id
        URLCache.shared.memoryCapacity = 100 * 1024 * 1024 // Increase to 100MB
        URLCache.shared.diskCapacity = 500 * 1024 * 1024 // 500MB disk cache
        
        self.isLoadingProfile = true
        self.cookiesEnabled = userDefaults.object(forKey: scopedKey("cookiesEnabled")) as? Bool ?? true
        self.isLoadingProfile = false
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        configuration.mediaTypesRequiringUserActionForPlayback = []

        configuration.websiteDataStore = makeWebsiteDataStore()

        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        let preferences = WKPreferences()
        preferences.isTextInteractionEnabled = true
        preferences.isElementFullscreenEnabled = true

        configuration.preferences = preferences
        configuration.userContentController = WKUserContentController()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

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

    func activeWebsiteDataStore() -> WKWebsiteDataStore {
        makeWebsiteDataStore()
    }

    private func makeWebsiteDataStore() -> WKWebsiteDataStore {
        guard cookiesEnabled else {
            return .nonPersistent()
        }

        guard let activeProfileID else {
            return .default()
        }

        return WKWebsiteDataStore(forIdentifier: activeProfileID)
    }

    private func scopedKey(_ key: String) -> String {
        guard let activeProfileID else { return key }
        return "profile.\(activeProfileID.uuidString).\(key)"
    }
}
