//
//  EaselView.swift
//  Illuminate 
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI
import WebKit

struct EaselView: NSViewRepresentable {
    let easelID: UUID
    let easelManager: EaselManager
    var tab: Tab? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(easelID: easelID, easelManager: easelManager, tab: tab)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = Coordinator.makeConfiguration(bridge: context.coordinator.bridge)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        if webView.configuration.preferences.responds(to: NSSelectorFromString("setDeveloperExtrasEnabled:")) {
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        webView.wantsLayer = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsMagnification = true

        if let tab = tab {
            try? tab.attachWebView(webView)
            tab.title = easelManager.easel(for: easelID)?.title ?? "Easel"
        }

        let easelURL = URL(string: "easel://easel/index.html")!
        webView.load(URLRequest(url: easelURL))
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.easelManager = easelManager
        context.coordinator.easelID = easelID
        context.coordinator.tab = tab
        if let tab, let easel = easelManager.easel(for: easelID), tab.title != easel.title {
            tab.title = easel.title
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.flushPendingSave()
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: EaselBridge.handlerName)
        nsView.stopLoading()
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, EaselBridgeDelegate {
        var easelID: UUID
        var easelManager: EaselManager
        weak var tab: Tab?
        let bridge = EaselBridge()
        weak var webView: WKWebView?
        private var pendingSaveTask: Task<Void, Never>?
        private var lastSentJSON: String?

        init(easelID: UUID, easelManager: EaselManager, tab: Tab? = nil) {
            self.easelID = easelID
            self.easelManager = easelManager
            self.tab = tab
            super.init()
            bridge.delegate = self
        }

        static func makeConfiguration(bridge: EaselBridge) -> WKWebViewConfiguration {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            if config.preferences.responds(to: NSSelectorFromString("setAllowFileAccessFromFileURLs:")) {
                config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
            }
            if config.preferences.responds(to: NSSelectorFromString("setAllowUniversalAccessFromFileURLs:")) {
                config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
            }
            if config.responds(to: NSSelectorFromString("setAllowFileAccessFromFileURLs:")) {
                config.setValue(true, forKey: "allowFileAccessFromFileURLs")
            }
            if config.responds(to: NSSelectorFromString("setAllowUniversalAccessFromFileURLs:")) {
                config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
            }
            // Custom scheme easel:// → local bundle, avoids file:// Origin null CORS for ES modules
            config.setURLSchemeHandler(EaselURLSchemeHandler(), forURLScheme: "easel")
            let controller = WKUserContentController()
            EaselBridge.install(on: controller, handler: bridge)
            config.userContentController = controller
            return config
        }

        static var easelIndexURL: URL? {
            if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Easel/Resources") {
                return url
            }
            if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Resources") {
                return url
            }

            // TELL THE TROOPS TO FALLBACKKK
            if let resourceURL = Bundle.main.resourceURL {
                let candidates = [
                    resourceURL.appendingPathComponent("Easel/Resources/index.html"),
                    resourceURL.appendingPathComponent("Resources/index.html"),
                    resourceURL.appendingPathComponent("index.html"),
                ]
                for c in candidates where FileManager.default.fileExists(atPath: c.path) { return c }
            }
            // for development
            let devPaths = [
                "/Users/ethanhall/Desktop/Illuminate/Illuminate/Features/Easel/Resources/index.html",
            ]
            for p in devPaths {
                let u = URL(fileURLWithPath: p)
                if FileManager.default.fileExists(atPath: u.path) { return u }
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // no theme push — canvas stays light, prevents random dark flash
        }

        func easelDidBecomeReady(_ bridge: EaselBridge) {
            guard let webView else { return }
            let doc = easelManager.loadDocument(id: easelID)
            let json = doc?.canvasJSON ?? ""
            let escaped = json.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "window.loadEasel(`\(escaped)`);"
            webView.evaluateJavaScript(js) { _, err in
                if let err { AppLog.error("Easel loadEasel failed", error: err) }
            }
        }

        func easelDidChange(_ bridge: EaselBridge, json: String) {
            // debounce 650ms already in JS, but add Swift coalescing too
            pendingSaveTask?.cancel()
            pendingSaveTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    // Avoid redundant saves
                    if self.lastSentJSON == json { return }
                    self.lastSentJSON = json
                    self.easelManager.saveDocument(jsonString: json, id: self.easelID)
                }
            }
        }

        func easelDidRequestTitleChange(_ bridge: EaselBridge, title: String) {
            easelManager.renameEasel(id: easelID, to: title)
        }

        func easelDidReceivePreview(_ bridge: EaselBridge, dataURL: String) {
            easelManager.savePreview(dataURL: dataURL, id: easelID)
        }

        func flushPendingSave() {
            pendingSaveTask?.cancel()
            if let webView, let json = lastSentJSON {
                // Already saved, nothing
                _ = webView
                _ = json
            }
        }
    }
}
