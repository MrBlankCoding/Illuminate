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
    let webKitManager: WebKitManager
    let passwordService: PasswordService
    let tabManager: TabManager
    let trackerBlockingService: TrackerBlockingService
    let historyManager: HistoryManager
    let websitePermissionService: WebsitePermissionService
    @ObservedObject var canvasFingerprintingService: CanvasFingerprintingService
    let userInterfaceStyle: TabManager.UIStyle

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tab: tab,
            tabManager: tabManager,
            webScriptBridge: WebScriptBridge.shared,
            trackerBlockingService: trackerBlockingService,
            dohService: DNSOverHTTPSService.shared,
            faviconCache: FaviconCache.shared,
            passwordService: passwordService,
            webKitManager: webKitManager,
            historyManager: historyManager,
            websitePermissionService: websitePermissionService
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        if tab.webView == nil {
            let configuration = tab.customWebViewConfiguration ?? webKitManager.makeConfiguration()
            tab.createWebViewIfNeeded(configuration: configuration, webKitManager: webKitManager)
        }

        guard let webView = tab.webView else {
            let fallback = webKitManager.makeWebView()
            return fallback
        }

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsLinkPreview = true
        webView.allowsBackForwardNavigationGestures = tab.id == tabManager.activeTabID
        if let illuminateWebView = webView as? IlluminateWebView {
            illuminateWebView.onIlluminateDownload = { [weak tab, weak webView] event in
                guard let tab, let webView else { return }
                triggerIlluminateDownload(for: tab, in: webView, event: event)
            }
        }
        WebScriptBridge.shared.installScripts(
            on: webView.configuration.userContentController,
            handler: context.coordinator,
            colorScheme: Coordinator.resolvedScheme(for: userInterfaceStyle),
            canvasFingerprintingProtectionEnabled: canvasFingerprintingService.isEnabled
        )

        if let url = tab.url, webView.url == nil {
            if url.isFileURL {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                webView.load(makeRequest(for: url))
            }
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let shouldEnableGestures = tab.id == tabManager.activeTabID
        if nsView.allowsBackForwardNavigationGestures != shouldEnableGestures {
            nsView.allowsBackForwardNavigationGestures = shouldEnableGestures
        }

        let resolvedScheme = Coordinator.resolvedScheme(for: userInterfaceStyle)
        let fingerprintingEnabled = canvasFingerprintingService.isEnabled

        if context.coordinator.lastAppliedScheme != resolvedScheme ||
           context.coordinator.lastFingerprintingEnabled != fingerprintingEnabled {

            context.coordinator.lastAppliedScheme = resolvedScheme
            context.coordinator.lastFingerprintingEnabled = fingerprintingEnabled

            WebScriptBridge.shared.installScripts(
                on: nsView.configuration.userContentController,
                handler: context.coordinator,
                colorScheme: resolvedScheme,
                canvasFingerprintingProtectionEnabled: fingerprintingEnabled
            )
        }

        if let illuminateWebView = nsView as? IlluminateWebView,
           !context.coordinator.hasInstalledDownloadHandler {
            context.coordinator.hasInstalledDownloadHandler = true
            illuminateWebView.onIlluminateDownload = { [weak tab, weak nsView] event in
                guard let tab, let nsView else { return }
                triggerIlluminateDownload(for: tab, in: nsView, event: event)
            }
        }
    }

    private func triggerIlluminateDownload(for tab: Tab, in webView: WKWebView, event: NSEvent) {
        let pointInView = webView.convert(event.locationInWindow, from: nil)
        let javaScript = """
        (() => {
            const x = \(pointInView.x);
            const y = \(pointInView.y);
            let element = document.elementFromPoint(x, y);
            while (element) {
                if (element.currentSrc) return element.currentSrc;
                if (element.src) return element.src;
                if (element.href) return element.href;
                element = element.parentElement;
            }
            return null;
        })();
        """

        webView.evaluateJavaScript(javaScript) { result, error in
            if let error {
                AppLog.download("Failed to resolve clicked element URL from context menu error=\(error.localizedDescription)")
            }

            let resolvedURL = (result as? String).flatMap(URL.init(string:)) ?? tab.url
            guard let resolvedURL, resolvedURL.scheme != "illuminate" else { return }

            let suggestedFilename = resolvedURL.lastPathComponent.isEmpty ? "download" : resolvedURL.lastPathComponent
            AppLog.download("IlluminateWebView menu download triggered url=\(resolvedURL.absoluteString) suggestedFilename=\(suggestedFilename) clickPoint=\(pointInView.x),\(pointInView.y)")
            DownloadManager.shared.startDownload(from: resolvedURL, suggestedFilename: suggestedFilename, profileID: tabManager.profileID)
        }
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
}
