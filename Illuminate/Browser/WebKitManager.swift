//
//  WebKitManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation
import WebKit
import Combine
import ObjectiveC

@MainActor
final class WebKitManager: ObservableObject {
    private static var hasConfiguredGlobalCache = false
    
    @Published var cookiesEnabled: Bool = true {
        didSet {
            guard oldValue != cookiesEnabled else { return }
            sharedWebsiteDataStore = nil
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            AppLog.info("WebKitManager: Setting changed cookiesEnabled=\(cookiesEnabled)")
            userDefaults.set(cookiesEnabled, forKey: scopedKey("cookiesEnabled"))
        }
    }

    @Published var httpsOnlyEnabled: Bool = false {
        didSet {
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            AppLog.info("WebKitManager: Setting changed httpsOnlyEnabled=\(httpsOnlyEnabled)")
            userDefaults.set(httpsOnlyEnabled, forKey: scopedKey("httpsOnlyEnabled"))
        }
    }

    private let userDefaults: UserDefaults
    private var activeProfileID: UUID?
    private var isLoadingProfile = false
    private let isPersistenceEnabled: Bool
    private var cachedUserAgent: String?
    private let extensionManager: ExtensionManager
    
    private var sharedWebsiteDataStore: WKWebsiteDataStore?

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
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
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

        #if DEBUG
        webView.isInspectable = true
        #endif

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
        
        // Memory Cache: ~2% of RAM, capped between 128MB and 512MB
        let memoryLimit = min(max(physicalMemory / 50, 128 * 1024 * 1024), 512 * 1024 * 1024)
        
        // Disk Cache: ~5% of free space, capped between 512MB and 2GB
        let diskLimit: UInt64
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = attributes[.systemFreeSize] as? UInt64 {
            diskLimit = min(max(freeSpace / 20, 512 * 1024 * 1024), 2 * 1024 * 1024 * 1024)
        } else {
            diskLimit = 1000 * 1024 * 1024 // Fallback to 1GB
        }
        
        URLCache.shared.memoryCapacity = Int(memoryLimit)
        URLCache.shared.diskCapacity = Int(diskLimit)
        
        AppLog.info("Dynamic cache configured: Memory=\(memoryLimit / 1024 / 1024)MB, Disk=\(diskLimit / 1024 / 1024)MB")
    }
}
