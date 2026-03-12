//
//  WebViewCoordinator.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import WebKit
import SwiftUI

extension WebViewRepresentable {
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {

        private weak var tab: Tab?
        private let tabManager: TabManager
        private let webScriptBridge: WebScriptBridge
        private let adBlockService: AdBlockService
        private let dohService: DNSOverHTTPSService
        private let safeBrowsing: SafeBrowsingManager
        private let faviconCache: FaviconCache

        private let circuitBreaker = WebProcessCircuitBreaker()
        private var isRestoringHibernatedState = false
        private var lastAppliedStyle: TabManager.UIStyle?
        private var lastAppliedContentRuleList: WKContentRuleList?
        private weak var contextMenuWebView: WKWebView?
        var lastLoadedURL: URL?

        private static func colorSchemeScript(for scheme: String) -> String {
            """
            (() => {
                const id = "illuminate-force-color-scheme";
                let el = document.getElementById(id) ?? document.createElement("style");
                el.id = id;
                el.textContent = ":root, html { color-scheme: \(scheme) !important; }";
                if (!el.parentNode) document.documentElement.appendChild(el);
            })();
            """
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
            adBlockService: AdBlockService,
            dohService: DNSOverHTTPSService,
            safeBrowsing: SafeBrowsingManager,
            faviconCache: FaviconCache
        ) {
            self.tab = tab
            self.tabManager = tabManager
            self.webScriptBridge = webScriptBridge
            self.adBlockService = adBlockService
            self.dohService = dohService
            self.safeBrowsing = safeBrowsing
            self.faviconCache = faviconCache
            self.lastLoadedURL = tab.url
        }

        func restoreHibernatedStateIfNeeded(into webView: WKWebView) {
            guard !isRestoringHibernatedState else { return }
            isRestoringHibernatedState = true
            defer { isRestoringHibernatedState = false }
            restoreHibernatedState(into: webView)
        }

        private func restoreHibernatedState(into webView: WKWebView) {
            guard let tab, tab.isHibernated, let state = tab.hibernatedState else { return }

            if let restoredURL = state.currentURL {
                let request = URLRequest(url: restoredURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
                webView.load(request)
                lastLoadedURL = restoredURL
                tab.url = restoredURL
            }

            webView.pageZoom = state.zoomScale
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                webView.evaluateJavaScript(
                    "window.scrollTo(\(state.scrollX), \(state.scrollY));",
                    completionHandler: nil
                )
            }

            if let title = state.title { tab.title = title }
            tab.isHibernated = false
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping (Any?, String?) -> Void
        ) {
            self.userContentController(userContentController, didReceive: message)
            replyHandler(nil, nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "passwordBridge":
                handlePasswordMessage(message)
            case webScriptBridge.metadataBridgeName:
                handleMetadataMessage(message)
            default:
                break
            }
        }

        private func handleMetadataMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, let tab = self.tab else { return }
                if let hoverURL = body["hoverURL"] as? String {
                    let newValue: String? = hoverURL.isEmpty ? nil : hoverURL
                    if tab.hoveredLinkURLString != newValue { tab.hoveredLinkURLString = newValue }
                    return
                }
                if body["hoverURL"] is NSNull {
                    if tab.hoveredLinkURLString != nil { tab.hoveredLinkURLString = nil }
                    return
                }

                if let title = body["title"] as? String, !title.isEmpty, tab.title != title {
                    tab.title = title
                }
                if let hex = body["themeColor"] as? String {
                    let newColor = Color(hex: hex)
                    if tab.themeColor != newColor { tab.themeColor = newColor }
                }
                if let faviconString = body["favicon"] as? String,
                   let faviconURL = URL(string: faviconString) {
                    Task { await self.loadFavicon(from: faviconURL, for: tab) }
                }
            }
        }

        private func handlePasswordMessage(_ message: WKScriptMessage) {
            guard
                let body = message.body as? [String: Any],
                let type = body["type"] as? String,
                let url = message.webView?.url?.absoluteString
            else { return }

            switch type {
            case "savePassword":
                guard
                    let username = body["username"] as? String,
                    let password = body["password"] as? String
                else { return }
                DispatchQueue.main.async {
                    PasswordService.shared.savePassword(url: url, username: username, passwordData: password)
                }

            case "fieldsDetected":
                let passwords = PasswordService.shared.fetchPasswords(for: url)
                guard let first = passwords.first, let webView = message.webView else { return }
                // Pass credentials as JSON rather than interpolating them directly into
                // a JS string literal, which would break on special characters and is
                // a potential injection vector.
                let payload: [String: String] = ["username": first.username, "password": first.passwordData]
                guard
                    let data = try? JSONEncoder().encode(payload),
                    let json = String(data: data, encoding: .utf8)
                else { return }
                let script = """
                (() => {
                    const c = \(json);
                    const pass = document.querySelector('input[type="password"]');
                    const user = document.querySelector('input[type="text"], input[type="email"], input:not([type])');
                    if (pass) pass.value = c.password;
                    if (user) user.value = c.username;
                })();
                """
                Task { _ = try? await webView.evaluateJavaScript(script) }

            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard let tab else { return }
            tab.isLoading = true
            tab.lastNavigationHadNetworkError = false
            tab.hoveredLinkURLString = nil
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            lastLoadedURL = webView.url
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let tab else { return }
            lastLoadedURL = webView.url

            tab.isLoading = false
            tab.title = webView.title?.nilIfEmpty ?? tab.title
            tab.hasMixedContentWarning = !webView.hasOnlySecureContent
            if tab.hasMixedContentWarning {
                AppLog.security("Mixed content warning at \(webView.url?.absoluteString ?? "unknown URL")")
            }
            tab.refreshSnapshot()

            if let lastAppliedStyle {
                applyWebAppearance(to: webView, style: lastAppliedStyle)
            }
            circuitBreaker.reset()

            if tab.id == tabManager.activeTabID {
                DNSPreFetcher.shared.prefetchLinks(in: webView)
            }

            webView.evaluateJavaScript(Self.videoDetectionScript) { [weak tab] result, _ in
                if let hasVideo = result as? Bool {
                    DispatchQueue.main.async { tab?.hasPiPCandidate = hasVideo }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            guard let tab else { return }
            tab.isLoading = false
            tab.lastNavigationHadNetworkError = isNetworkError(error)
            tab.lastNetworkErrorMessage = error.localizedDescription
            tab.isDNSError = isDNSError(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard circuitBreaker.canReloadAfterTermination() else {
                AppLog.info("Circuit breaker prevented reload loop")
                tab?.lastNavigationHadNetworkError = true
                tab?.lastNetworkErrorMessage = "Web process repeatedly crashed. Reload paused by circuit breaker."
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
            guard dohService.shouldAllowRequest(for: url) else {
                AppLog.security("Blocked non-HTTP(S) request: \(url.absoluteString)")
                decisionHandler(.cancel)
                return
            }
            guard !safeBrowsing.isUnsafe(url) else {
                AppLog.security("Blocked unsafe URL: \(url.absoluteString)")
                decisionHandler(.cancel)
                return
            }
            decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            DownloadManager.shared.addDownload(download)
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            DownloadManager.shared.addDownload(download)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Intercept target=_blank and similar popups as new tabs
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

        // CONTEXT MENU
        // should be extended in the future
        // do people use mark?
        // mark...?

        func webView(
            _ webView: WKWebView,
            contextMenu: NSMenu,
            forElement elementInfo: Any,
            completionHandler: @escaping (NSMenu?) -> Void
        ) {
            contextMenuWebView = webView
            contextMenu.addItem(.separator())

            let findItem = NSMenuItem(title: "Find in Page…", action: #selector(triggerFindInPage), keyEquivalent: "f")
            findItem.keyEquivalentModifierMask = .command
            findItem.target = self
            contextMenu.addItem(findItem)

            // KVC-based image URL extraction — fragile but unavoidable without private API.
            if let info = elementInfo as? NSObject,
               let imageURL = info.value(forKey: "imageURL") as? URL {
                contextMenu.addItem(.separator())

                let downloadItem = NSMenuItem(title: "Download Image…", action: #selector(downloadImage(_:)), keyEquivalent: "")
                downloadItem.target = self
                downloadItem.representedObject = imageURL
                contextMenu.addItem(downloadItem)

                let copyItem = NSMenuItem(title: "Copy Image Address", action: #selector(copyImageAddress(_:)), keyEquivalent: "")
                copyItem.target = self
                copyItem.representedObject = imageURL
                contextMenu.addItem(copyItem)
            }

            completionHandler(contextMenu)
        }

        @objc private func downloadImage(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            if let webView = contextMenuWebView {
                Task { await webView.startDownload(using: URLRequest(url: url)) }
            } else {
                DownloadManager.shared.startDownload(from: url)
            }
        }

        @objc private func copyImageAddress(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        }

        @objc private func triggerFindInPage() {
            NotificationCenter.default.post(name: .findInPage, object: nil)
        }

        func applyWebAppearance(to webView: WKWebView, style: TabManager.UIStyle) {
            guard lastAppliedStyle != style else { return }
            lastAppliedStyle = style

            let scheme: String
            switch style {
            case .dark:   scheme = "dark"
            case .light:  scheme = "light"
            case .system:
                let best = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
                scheme = (best == .darkAqua) ? "dark" : "light"
            }

            webView.evaluateJavaScript(Self.colorSchemeScript(for: scheme), completionHandler: nil)
        }

        func applyContentRules(to webView: WKWebView, ruleList: WKContentRuleList?) {
            guard lastAppliedContentRuleList !== ruleList else { return }
            let ucc = webView.configuration.userContentController
            ucc.removeAllContentRuleLists()
            if let ruleList { ucc.add(ruleList) }
            lastAppliedContentRuleList = ruleList
        }

        private func loadFavicon(from url: URL, for tab: Tab) async {
            if let cached = faviconCache.image(for: url) {
                await MainActor.run { tab.favicon = cached }
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = NSImage(data: data) {
                    faviconCache.set(image, for: url)
                    await MainActor.run { tab.favicon = image }
                }
            } catch {
                AppLog.info("Failed to load favicon from \(url): \(error.localizedDescription)")
            }
        }

        private func isNetworkError(_ error: Error) -> Bool {
            (error as NSError).domain == NSURLErrorDomain
        }

        private func isDNSError(_ error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && 
                   (nsError.code == NSURLErrorCannotFindHost || nsError.code == NSURLErrorDNSLookupFailed)
        }
    }
}

// always strings

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
