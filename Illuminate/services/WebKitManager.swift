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
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            userDefaults.set(cookiesEnabled, forKey: scopedKey("cookiesEnabled"))
        }
    }

    @Published var httpsOnlyEnabled: Bool = false {
        didSet {
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            userDefaults.set(httpsOnlyEnabled, forKey: scopedKey("httpsOnlyEnabled"))
        }
    }

    private let userDefaults: UserDefaults
    private var activeProfileID: UUID?
    private var isLoadingProfile = false
    private let isPersistenceEnabled: Bool

    init(profileID: UUID? = nil, userDefaults: UserDefaults = .standard, isPersistenceEnabled: Bool = true) {
        self.userDefaults = userDefaults
        self.activeProfileID = profileID
        self.isPersistenceEnabled = isPersistenceEnabled
        URLCache.shared.memoryCapacity = 100 * 1024 * 1024 // Increase to 100MB
        URLCache.shared.diskCapacity = 500 * 1024 * 1024 // 500MB disk cache
        
        self.isLoadingProfile = true
        self.cookiesEnabled = isPersistenceEnabled
            ? (userDefaults.object(forKey: scopedKey("cookiesEnabled")) as? Bool ?? true)
            : true
        self.httpsOnlyEnabled = isPersistenceEnabled
            ? (userDefaults.object(forKey: scopedKey("httpsOnlyEnabled")) as? Bool ?? false)
            : false
        self.isLoadingProfile = false
    }

    convenience init(profile: BrowserProfile, userDefaults: UserDefaults = .standard, isPersistenceEnabled: Bool = true) {
        self.init(profileID: profile.id, userDefaults: userDefaults, isPersistenceEnabled: isPersistenceEnabled)
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
        applyBrowserUserAgent(to: webView)
        return webView
    }

    // legacy way 
    /*
    func applySafariUserAgent(to webView: WKWebView) {
        let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15"
        webView.customUserAgent = safariUA
        AppLog.info("Set custom UA: \(safariUA)")
    }
    */

    // try to be a bit more modern 
    func applyBrowserUserAgent(to webView: WKWebView) {
        webView.evaluateJavaScript("navigator.userAgent") { result, error in
            
            Task { @MainActor in
                guard let defaultUA = result as? String else {
                    AppLog.info("Could not get default WebKit UA: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                let chromeVersion = await ChromeVersionFetcher.fetchLatestStableVersion()

                let enhancedUA = "\(defaultUA) Chrome/\(chromeVersion)"

                webView.customUserAgent = enhancedUA

                AppLog.info("Set enhanced UA: \(enhancedUA)")
            }
        }
    }

    func activeWebsiteDataStore() -> WKWebsiteDataStore {
        makeWebsiteDataStore()
    }

    private func makeWebsiteDataStore() -> WKWebsiteDataStore {
        guard isPersistenceEnabled else {
            return .nonPersistent()
        }

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
