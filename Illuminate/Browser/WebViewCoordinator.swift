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

        private let circuitBreaker = WebProcessCircuitBreaker()
        var lastAppliedFaviconURL: URL?
        private var contextMenuDownloadURL: URL?
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

        private static let videoDetectionScript = """
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


        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard let tab else { return }
            tab.isLoading = true
            tab.networkError = nil
            tab.hoveredLinkURLString = nil
            lastAppliedFaviconURL = nil
            syncTabURL(from: webView, for: tab)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            lastLoadedURL = webView.url
            if let tab {
                syncTabURL(from: webView, for: tab)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let tab else { return }
            lastLoadedURL = webView.url
            syncTabURL(from: webView, for: tab)

            tab.isLoading = false
            tabManager.finishInitialTabPreloading(for: tab.id)
            tab.title = webView.title?.nilIfEmpty ?? tab.title
            tab.hasMixedContentWarning = !webView.hasOnlySecureContent

            circuitBreaker.reset()

            if tab.id == tabManager.activeTabID {
                DNSPreFetcher.shared.prefetchLinks(in: webView)
            }

            if let fallbackFaviconURL = defaultFaviconURL(for: webView.url) {
                Task { await self.loadFavicon(from: fallbackFaviconURL, for: tab) }
            }

            if let finishedURL = webView.url {
                let pageTitle = webView.title?.nilIfEmpty ?? finishedURL.host ?? finishedURL.absoluteString
                let faviconURLForHistory: URL? = defaultFaviconURL(for: finishedURL)
                let tabID = tab.id
                Task { @MainActor [weak self] in
                    self?.historyManager.record(
                        url: finishedURL,
                        title: pageTitle,
                        faviconURL: faviconURLForHistory,
                        tabID: tabID
                    )
                }
            }

            webView.evaluateJavaScript(Self.videoDetectionScript) { [weak tab] result, _ in
                if let hasVideo = result as? Bool {
                    DispatchQueue.main.async { tab?.hasPiPCandidate = hasVideo }
                }
            }
        }

        private func syncTabURL(from webView: WKWebView, for tab: Tab) {
            guard let url = webView.url, tab.url != url else { return }
            tab.url = url
            if tab.id == tabManager.activeTabID {
                tabManager.syncActiveTabURL()
            }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            guard let tab else { return }
            tab.isLoading = false
            tabManager.finishInitialTabPreloading(for: tab.id)
            guard !isCancellationError(error) else {
                tab.networkError = nil
                return
            }
            tab.networkError = classifyError(error, url: tab.url)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            guard let tab else { return }
            tab.isLoading = false
            tabManager.finishInitialTabPreloading(for: tab.id)
            guard !isCancellationError(error) else {
                tab.networkError = nil
                return
            }
            tab.networkError = classifyError(error, url: tab.url)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard circuitBreaker.canReloadAfterTermination() else {
                AppLog.info("Circuit breaker prevented reload loop")
                tab?.networkError = .generic(message: "The web process repeatedly crashed. Reload paused to protect your device.")
                return
            }
            webView.reload()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme?.lowercased() == "illuminate" {
                decisionHandler(.cancel)
                DispatchQueue.main.async { [weak self] in
                    self?.tab?.load(url: url)
                }
                return
            }

            // command click handeling -> open in nuevo tab
            if navigationAction.navigationType == .linkActivated,
               navigationAction.modifierFlags.contains(.command)
            {
                decisionHandler(.cancel)
                DispatchQueue.main.async { [weak self] in
                    self?.tabManager.createTab(url: url)
                }
                return
            }

            let isLocalMainFrameNavigation = url.isFileURL && (navigationAction.targetFrame?.isMainFrame ?? false)
            guard isLocalMainFrameNavigation || dohService.shouldAllowRequest(for: url) else {
                AppLog.security("Blocked non-HTTP(S) request: \(AppLog.sanitizedURL(url))")
                decisionHandler(.cancel)
                return
            }
            guard !SafeBrowsingManager.isUnsafe(url) else {
                AppLog.security("Blocked unsafe URL: \(AppLog.sanitizedURL(url))")
                decisionHandler(.cancel)
                return
            }

            if webKitManager.httpsOnlyEnabled,
               url.scheme?.lowercased() == "http"
            {
                let host = url.host?.lowercased() ?? ""
                let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"
                if !isLocalhost {
                    AppLog.security("HTTPS-only: blocked HTTP navigation to \(AppLog.sanitizedURL(url))")
                    decisionHandler(.cancel)
                    if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                        components.scheme = "https"
                        if let upgraded = components.url {
                            DispatchQueue.main.async { [weak self] in
                                self?.tab?.load(url: upgraded)
                            }
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                self?.tab?.networkError = .blocked(
                                    reason: "\(url.host ?? url.absoluteString) doesn't support HTTPS. HTTPS-only mode prevented this connection."
                                )
                            }
                        }
                    }
                    return
                }
            }

            if navigationAction.shouldPerformDownload,
               shouldHandleDownloadOutsideWebKit(for: url)
            {
                AppLog.download("Intercepted navigationAction download outside WebKit url=\(AppLog.sanitizedURL(url))")
                DownloadManager.shared.startDownload(
                    using: navigationAction.request,
                    suggestedFilename: url.lastPathComponent.nilIfEmpty,
                    profileID: tabManager.profileID
                )
                decisionHandler(.cancel)
                return
            }

            if let frameInfo = navigationAction.targetFrame,
               !frameInfo.isMainFrame,
               let topURL = navigationAction.sourceFrame.webView?.url ?? tab?.url,
               let firstParty = topURL.eTLDPlusOne,
               let thirdParty = url.eTLDPlusOne,
               thirdParty != firstParty
            {
                Task { @MainActor [weak self] in
                    self?.trackerBlockingService.record(
                        thirdPartyDomain: thirdParty,
                        seenOn: firstParty
                    )
                }
            }

            decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.response.mimeType?.lowercased() == "application/pdf" {
                if navigationResponse.isForMainFrame,
                   let url = navigationResponse.response.url,
                   let viewerURL = IlluminatePage.pdfViewerURL(for: url)
                {
                    decisionHandler(.cancel)
                    DispatchQueue.main.async { [weak self] in
                        self?.tab?.load(url: viewerURL)
                    }
                } else {
                    decisionHandler(.allow)
                }
                return
            }

            if !navigationResponse.canShowMIMEType,
               let url = navigationResponse.response.url,
               shouldHandleDownloadOutsideWebKit(for: url)
            {
                AppLog.download("Intercepted navigationResponse download outside WebKit url=\(AppLog.sanitizedURL(url))")
                DownloadManager.shared.startDownload(
                    using: URLRequest(url: url),
                    suggestedFilename: navigationResponse.response.suggestedFilename,
                    profileID: tabManager.profileID
                )
                decisionHandler(.cancel)
                return
            }

            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            if let request = download.originalRequest,
               let url = request.url,
               shouldHandleDownloadOutsideWebKit(for: url)
            {
                download.cancel()
                DownloadManager.shared.startDownload(using: request, profileID: tabManager.profileID)
                return
            }
            DownloadManager.shared.addDownload(download, from: webView, profileID: tabManager.profileID)
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            if let request = download.originalRequest,
               let url = request.url,
               shouldHandleDownloadOutsideWebKit(for: url)
            {
                download.cancel()
                DownloadManager.shared.startDownload(
                    using: request,
                    suggestedFilename: navigationResponse.response.suggestedFilename,
                    profileID: tabManager.profileID
                )
                return
            }
            DownloadManager.shared.addDownload(download, from: webView, profileID: tabManager.profileID)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                DispatchQueue.main.async { [weak self] in
                    self?.tabManager.createTab(url: navigationAction.request.url)
                }
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            guard let window = webView.window else { completionHandler(); return }
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: window) { _ in completionHandler() }
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            let types: [WebsitePermissionType]
            switch type {
            case .camera:
                types = [.camera]
            case .microphone:
                types = [.microphone]
            case .cameraAndMicrophone:
                types = [.camera, .microphone]
            @unknown default:
                decisionHandler(.deny)
                return
            }

            websitePermissionService.requestPermission(
                for: displayOrigin(origin),
                types: types
            ) { decision in
                decisionHandler(decision == .allow ? .grant : .deny)
            }
        }

        @objc(_webViewDidRequestPointerLock:completionHandler:)
        func grantPointerLockRequest(for webView: WKWebView, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            guard let window = webView.window else { completionHandler(false); return }
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: window) { response in
                completionHandler(response == .alertFirstButtonReturn)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            guard let window = webView.window else { completionHandler(nil); return }
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            input.stringValue = defaultText ?? ""
            alert.accessoryView = input
            alert.beginSheetModal(for: window) { response in
                completionHandler(response == .alertFirstButtonReturn ? input.stringValue : nil)
            }
        }

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            panel.begin { result in
                completionHandler(result == .OK ? panel.urls : nil)
            }
        }

        func webView(
            _ webView: WKWebView,
            contextMenu: NSMenu,
            forElement elementInfo: Any,
            completionHandler: @escaping (NSMenu?) -> Void
        ) {
            contextMenuDownloadURL = preferredDownloadURL(from: elementInfo)
            contextMenu.addItem(.separator())

            let illuminateDownloadItem = NSMenuItem(title: "[Illuminate] Download", action: #selector(triggerIlluminateDownload), keyEquivalent: "")
            illuminateDownloadItem.target = self
            contextMenu.addItem(illuminateDownloadItem)

            let findItem = NSMenuItem(title: "Find in Page…", action: #selector(triggerFindInPage), keyEquivalent: "f")
            findItem.keyEquivalentModifierMask = .command
            findItem.target = self
            contextMenu.addItem(findItem)

            completionHandler(contextMenu)
        }

        @objc private func triggerFindInPage() {
            NotificationCenter.default.post(name: .findInPage, object: nil)
        }

        @objc private func triggerIlluminateDownload() {
            guard let url = contextMenuDownloadURL ?? tab?.url, url.scheme != "illuminate" else { return }
            let suggestedFilename = url.lastPathComponent.nilIfEmpty ?? "download"
            DownloadManager.shared.startDownload(from: url, suggestedFilename: suggestedFilename, profileID: tabManager.profileID)
        }

        private func preferredDownloadURL(from elementInfo: Any) -> URL? {
            if let object = elementInfo as? NSObject {
                for key in ["imageURL", "mediaURL", "linkURL", "url"] {
                    if let value = object.value(forKey: key) as? URL { return value }
                    if let raw = object.value(forKey: key) as? String, let url = URL(string: raw) { return url }
                }
            }
            let mirror = Mirror(reflecting: elementInfo)
            for child in mirror.children {
                guard let label = child.label?.lowercased() else { continue }
                guard ["imageurl", "mediaurl", "linkurl", "url"].contains(label) else { continue }
                if let url = child.value as? URL { return url }
                if let raw = child.value as? String, let url = URL(string: raw) { return url }
            }
            return nil
        }

        func resolveFaviconURL(from rawValue: String, pageURL: URL?) -> URL? {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let resolvedURL: URL?
            if trimmed.hasPrefix("data:") {
                resolvedURL = URL(string: trimmed)
            } else if let pageURL {
                resolvedURL = URL(string: trimmed, relativeTo: pageURL)?.absoluteURL
            } else {
                resolvedURL = URL(string: trimmed)
            }
            guard let resolvedURL else { return nil }
            switch resolvedURL.scheme?.lowercased() {
            case "http", "https", "data", "webkit-extension": return resolvedURL
            default: return nil
            }
        }

        func displayOrigin(_ origin: WKSecurityOrigin) -> String {
            let port = origin.port > 0 ? ":\(origin.port)" : ""
            return "\(origin.protocol)://\(origin.host)\(port)"
        }

        func displayOrigin(for url: URL) -> String {
            guard let scheme = url.scheme, let host = url.host else { return url.absoluteString }
            let port = url.port.map { ":\($0)" } ?? ""
            return "\(scheme)://\(host)\(port)"
        }

        private func defaultFaviconURL(for pageURL: URL?) -> URL? {
            guard
                let pageURL,
                let scheme = pageURL.scheme?.lowercased(),
                let host = pageURL.host,
                (scheme == "http" || scheme == "https" || scheme == "webkit-extension")
            else { return nil }
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = "/favicon.ico"
            return components.url
        }

        private func shouldHandleDownloadOutsideWebKit(for url: URL) -> Bool {
            ["http", "https", "webkit-extension"].contains(url.scheme?.lowercased() ?? "")
        }

        func loadFavicon(from url: URL, for tab: Tab) async {
            guard tab.favicon == nil else { return }
            if let image = await FaviconLoader.shared.loadFavicon(from: url) {
                await MainActor.run { tab.favicon = image }
                return
            }
        }

        private func classifyError(_ error: Error, url: URL?) -> NetworkErrorKind {
            let nsError = error as NSError
            guard nsError.domain == NSURLErrorDomain else {
                return .generic(message: error.localizedDescription)
            }

            switch nsError.code {
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                let host = url?.host ?? "The server"
                return .dns(host: host)

            case NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid,
                 NSURLErrorClientCertificateRequired,
                 NSURLErrorClientCertificateRejected:
                let detail = nsError.localizedDescription
                return .tls(message: detail)

            case NSURLErrorNotConnectedToInternet:
                return .noConnection(message: "Your device is not connected to the internet. Check your Wi-Fi or Ethernet connection and try again.")

            case NSURLErrorNetworkConnectionLost:
                return .noConnection(message: "The network connection was lost. Check your connection and try again.")

            case NSURLErrorTimedOut:
                return .noConnection(message: "The connection timed out. The server may be busy or your connection may be slow.")

            case NSURLErrorCannotConnectToHost, -102:
                let host = url?.host ?? "the server"
                return .noConnection(message: "A connection to \(host) could not be established.")

            default:
                return .generic(message: error.localizedDescription)
            }
        }

        private func isCancellationError(_ error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
