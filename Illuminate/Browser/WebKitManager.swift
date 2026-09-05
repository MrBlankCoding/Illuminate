//
//  WebKitManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation
import Observation
import WebKit
import ObjectiveC

@MainActor
@Observable
final class WebKitManager {
    static let javascriptEnabledKey = "browser.javascriptEnabled"

    @ObservationIgnored private static var hasConfiguredGlobalCache = false
    
    var cookiesEnabled: Bool = true {
        didSet {
            guard oldValue != cookiesEnabled else { return }
            sharedWebsiteDataStore = nil
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            AppLog.info("WebKitManager: Setting changed cookiesEnabled=\(cookiesEnabled)")
            userDefaults.set(cookiesEnabled, forKey: scopedKey("cookiesEnabled"))
        }
    }

    var httpsOnlyEnabled: Bool = false {
        didSet {
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            AppLog.info("WebKitManager: Setting changed httpsOnlyEnabled=\(httpsOnlyEnabled)")
            userDefaults.set(httpsOnlyEnabled, forKey: scopedKey("httpsOnlyEnabled"))
        }
    }

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var activeProfileID: UUID?
    @ObservationIgnored private var isLoadingProfile = false
    @ObservationIgnored private let isPersistenceEnabled: Bool
    @ObservationIgnored private var cachedUserAgent: String?
    @ObservationIgnored private let extensionManager: ExtensionManager
    
    @ObservationIgnored private var sharedWebsiteDataStore: WKWebsiteDataStore?

    var currentUserAgent: String? {
        cachedUserAgent
    }

    func fetchUserAgent() async -> String {
        if let cached = cachedUserAgent {
            return cached
        }
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("navigator.userAgent") { result, _ in
                let defaultUA = (result as? String) ?? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
                Task { @MainActor [weak self] in
                    let chromeVersion = await ChromeVersionFetcher.fetchLatestStableVersion()
                    let enhancedUA = "\(defaultUA) Chrome/\(chromeVersion)"
                    self?.cachedUserAgent = enhancedUA
                    continuation.resume(returning: enhancedUA)
                }
            }
        }
    }

    init(profileID: UUID? = nil, userDefaults: UserDefaults = .standard, isPersistenceEnabled: Bool = true, extensionManager: ExtensionManager) {
        self.userDefaults = userDefaults
        self.activeProfileID = profileID
        self.isPersistenceEnabled = isPersistenceEnabled
        self.extensionManager = extensionManager
        
        if !Self.hasConfiguredGlobalCache {
            Self.hasConfiguredGlobalCache = true
            configureGlobalCache()
        }
        
        self.isLoadingProfile = true
        self.cookiesEnabled = isPersistenceEnabled
            ? (userDefaults.object(forKey: scopedKey("cookiesEnabled")) as? Bool ?? true)
            : true
        self.httpsOnlyEnabled = isPersistenceEnabled
            ? (userDefaults.object(forKey: scopedKey("httpsOnlyEnabled")) as? Bool ?? false)
            : false
        self.isLoadingProfile = false
    }

    convenience init(profile: BrowserProfile, userDefaults: UserDefaults = .standard, isPersistenceEnabled: Bool = true, extensionManager: ExtensionManager) {
        self.init(profileID: profile.id, userDefaults: userDefaults, isPersistenceEnabled: isPersistenceEnabled, extensionManager: extensionManager)
    }

    func prepareForRemoval() {
        AppLog.info("WebKitManager: Tearing down (profile: \(activeProfileID?.uuidString ?? "guest"))")
        sharedWebsiteDataStore = nil
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []

        configuration.websiteDataStore = activeWebsiteDataStore()
        let javascriptEnabled = UserDefaults.standard.object(forKey: Self.javascriptEnabledKey) as? Bool ?? true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = javascriptEnabled
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        let preferences = WKPreferences()
        preferences.isTextInteractionEnabled = true
        preferences.isElementFullscreenEnabled = true
        preferences.setValue(true, forKey: "developerExtrasEnabled")

        configuration.preferences = preferences
        configuration.userContentController = WKUserContentController()
        if extensionManager.hasEnabledExtensions {
            configuration.webExtensionController = extensionManager.controller
        }

        if let ua = cachedUserAgent, let chromeVersion = ua.components(separatedBy: " Chrome/").last {
             configuration.applicationNameForUserAgent = "Chrome/\(chromeVersion)"
        }

        return configuration
    }

    func makeWebView() -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        webView.wantsLayer = true
        if let scale = webView.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor {
            webView.layer?.contentsScale = scale
        }

        webView.layer?.drawsAsynchronously = true

        webView.isInspectable = true

        if let cachedUA = cachedUserAgent {
            webView.customUserAgent = cachedUA
        } else {
            applyBrowserUserAgent(to: webView)
        }
        return webView
    }

    func applyBrowserUserAgent(to webView: WKWebView) {
        if let cached = cachedUserAgent {
            webView.customUserAgent = cached
            return
        }

        webView.evaluateJavaScript("navigator.userAgent") { result, error in
            Task { @MainActor in
                guard let defaultUA = result as? String else {
                    AppLog.error("Could not get default WebKit UA", error: error)
                    return
                }

                let chromeVersion = await ChromeVersionFetcher.fetchLatestStableVersion()
                let enhancedUA = "\(defaultUA) Chrome/\(chromeVersion)"
                
                self.cachedUserAgent = enhancedUA
                webView.customUserAgent = enhancedUA

                AppLog.info("Set and cached enhanced UA: \(enhancedUA)")
            }
        }
    }

    func activeWebsiteDataStore() -> WKWebsiteDataStore {
        if let existing = sharedWebsiteDataStore {
            return existing
        }
        
        let store = makeWebsiteDataStore()
        sharedWebsiteDataStore = store
        return store
    }

    private func makeWebsiteDataStore() -> WKWebsiteDataStore {
        guard isPersistenceEnabled else {
            return .nonPersistent()
        }

        guard cookiesEnabled else {
            return .nonPersistent()
        }

        guard let activeProfileID else {
            return .nonPersistent()
        }

        return WKWebsiteDataStore(forIdentifier: activeProfileID)
    }

    private func scopedKey(_ key: String) -> String {
        guard let activeProfileID else { return key }
        return "profile.\(activeProfileID.uuidString).\(key)"
    }

    private func configureGlobalCache() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        // Memory Cache: ~3% of RAM, capped between 256MB and 2GB
        let memoryLimit = min(
            max(UInt64(Double(physicalMemory) * 0.03), 256 * 1024 * 1024),
            2 * 1024 * 1024 * 1024
        )

        // Disk Cache: ~2% of available space, capped between 512MB and 8GB.
        // Additionally never exceed 10% of available space, so near-full
        // disks don't get pushed further toward capacity by the floor.
        let diskLimit = computeDiskCacheLimit()

        URLCache.shared.memoryCapacity = Int(memoryLimit)
        URLCache.shared.diskCapacity = Int(diskLimit)

        AppLog.info("Dynamic cache configured: Memory=\(memoryLimit / 1024 / 1024)MB, Disk=\(diskLimit / 1024 / 1024)MB")
    }

    private func computeDiskCacheLimit() -> UInt64 {
        let minLimit: UInt64 = 512 * 1024 * 1024      // 512MB
        let maxLimit: UInt64 = 8 * 1024 * 1024 * 1024  // 8GB
        let fallback: UInt64 = 2 * 1024 * 1024 * 1024  // 2GB

        guard let availableCapacity = volumeAvailableCapacity(), availableCapacity > 0 else {
            AppLog.warning("Could not read volume capactiy")
            return fallback
        }

        let available = UInt64(availableCapacity)
        let target = min(max(UInt64(Double(available) * 0.02), minLimit), maxLimit)

        let safetyCap = UInt64(Double(available) * 0.10)
        return min(target, max(safetyCap, 0))
    }

    private func volumeAvailableCapacity() -> Int64? {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? homeURL.resourceValues(forKeys: keys) else { return nil }
        return values.volumeAvailableCapacityForImportantUsage
    }

    nonisolated static func cleanupContainersIfNeeded() {
        ContainerCleanup.cleanupContainersIfNeeded()
    }
}
