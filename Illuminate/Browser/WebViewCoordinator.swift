//
//  WebViewCoordinator.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import CoreLocation
import WebKit
import SwiftUI

extension WebViewRepresentable {
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {

        weak var tab: Tab?
        let tabManager: TabManager
        let webScriptBridge: WebScriptBridge
        let trackerBlockingService: TrackerBlockingService
        let dohService: DNSOverHTTPSService
        let faviconCache: FaviconCache
        let passwordService: PasswordService
        let webKitManager: WebKitManager
        let historyManager: HistoryManager
        let websitePermissionService: WebsitePermissionService
        let locationService = WebsiteLocationService()
        let notificationService = NotificationService.shared
        let preconnectManager = NavigationPreconnectManager.shared

        let circuitBreaker = WebProcessCircuitBreaker()
        var lastAppliedFaviconURL: URL?
        var contextMenuDownloadURL: URL?
        var hasInstalledDownloadHandler = false
        var lastLoadedURL: URL?
        var lastRequestedLoadURLString: String?
        var lastAppliedScheme: String?
        var lastFingerprintingEnabled: Bool?

        static func resolvedScheme(for style: TabManager.UIStyle) -> String {
            switch style {
            case .dark:
                return "dark"
            case .light:
                return "light"
            case .system:
                let best = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
                return (best == .darkAqua) ? "dark" : "light"
            }
        }

        static func resolvedAppearance(for style: TabManager.UIStyle) -> NSAppearance? {
            switch style {
            case .dark:
                return NSAppearance(named: .darkAqua)
            case .light:
                return NSAppearance(named: .aqua)
            case .system:
                return nil
            }
        }

        static let videoDetectionScript = """
        (() => {
            try {
                return Array.from(document.querySelectorAll('video'))
                    .some(v => { try { return v.readyState >= 2; } catch { return false; } });
            } catch { return false; }
        })();
        """

        init(
            tab: Tab,
            tabManager: TabManager,
            webScriptBridge: WebScriptBridge,
            trackerBlockingService: TrackerBlockingService,
            dohService: DNSOverHTTPSService,
            faviconCache: FaviconCache,
            passwordService: PasswordService,
            webKitManager: WebKitManager,
            historyManager: HistoryManager,
            websitePermissionService: WebsitePermissionService
        ) {
            self.tab = tab
            self.tabManager = tabManager
            self.webScriptBridge = webScriptBridge
            self.trackerBlockingService = trackerBlockingService
            self.dohService = dohService
            self.faviconCache = faviconCache
            self.passwordService = passwordService
            self.webKitManager = webKitManager
            self.historyManager = historyManager
            self.websitePermissionService = websitePermissionService
            self.lastLoadedURL = tab.url
        }


        func syncTabURL(from webView: WKWebView, for tab: Tab) {
            guard let url = webView.url, tab.url != url else { return }
            tab.url = url
            if tab.id == tabManager.activeTabID {
                tabManager.syncActiveTabURL()
            }
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
