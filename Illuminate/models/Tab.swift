//
//  Tab.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import AppKit
import Combine
import Foundation
import ObjectiveC
import SwiftUI
import WebKit

enum NetworkErrorKind: Equatable {
    case dns(host: String)
    case tls(message: String)
    case noConnection(message: String)
    case blocked(reason: String)
    case generic(message: String)

    var icon: String {
        switch self {
        case .dns:          return "exclamationmark.triangle.fill"
        case .tls:          return "lock.trianglebadge.exclamationmark.fill"
        case .noConnection: return "wifi.slash"
        case .blocked:      return "hand.raised.fill"
        case .generic:      return "exclamationmark.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .dns:          return "Site Can't Be Reached"
        case .tls:          return "Your Connection Is Not Private"
        case .noConnection: return "No Internet Connection"
        case .blocked:      return "Connection Blocked"
        case .generic:      return "Something Went Wrong"
        }
    }

    var detail: String {
        switch self {
        case .dns(let host):
            return "\(host)'s server IP address could not be found. Check that the address is correct and try again."
        case .tls(let message):
            return message
        case .noConnection(let message):
            return message
        case .blocked(let reason):
            return reason
        case .generic(let message):
            return message
        }
    }
}

private var webViewTabOwnerKey: UInt8 = 0

final class IlluminateWebView: WKWebView {
    var onIlluminateDownload: ((NSEvent) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        if layer?.contentsScale != window.backingScaleFactor {
            layer?.contentsScale = window.backingScaleFactor
        }
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let itemTitle = "[Illuminate] Download"
        menu.items.removeAll { $0.title == itemTitle }
        menu.items.removeAll { item in
            let normalized = item.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return normalized.contains("download")
                || normalized.contains("save image")
                || normalized.contains("save video")
                || normalized.contains("save audio")
        }

        guard onIlluminateDownload != nil else { return }

        let menuItem = NSMenuItem(
            title: itemTitle,
            action: #selector(triggerIlluminateDownload(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self
        menuItem.representedObject = event
        menu.addItem(.separator())
        menu.addItem(menuItem)
    }

    @objc private func triggerIlluminateDownload(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? NSEvent else { return }
        onIlluminateDownload?(event)
    }
}

@MainActor
final class Tab: ObservableObject, Identifiable {
    static let zoomChangedNotification = NSNotification.Name("app.zoomChanged")
    static let zoomLevelKey = "level"

    private enum ZoomBounds {
        static let min: CGFloat = 0.25
        static let max: CGFloat = 5.0
        static let step: CGFloat = 0.1
        static let `default`: CGFloat = 1.0
    }

    private static let snapshotMinInterval: TimeInterval = 10

    let id: UUID

    @Published var url: URL? {
        didSet {
            if oldValue != url {
                if let url, let page = IlluminatePage(url: url) {
                    self.title = page.tabTitle
                }
                saveMetadata()
            }
        }
    }
    @Published var title: String {
        didSet { if oldValue != title { saveMetadata() } }
    }
    @Published var favicon: NSImage?
    @Published var themeColor: Color?
    @Published var isLoading: Bool
    @Published var isHibernated: Bool
    @Published var hasMixedContentWarning: Bool
    @Published var networkError: NetworkErrorKind?
    @Published var hoveredLinkURLString: String?
    @Published var canGoBack: Bool = false

    var isDNSError: Bool {
        if case .dns = networkError { return true }
        return false
    }

    var lastNetworkErrorMessage: String? {
        networkError?.detail
    }

    var lastNavigationHadNetworkError: Bool {
        networkError != nil
    }
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var zoomLevel: Double = 1.0
    @Published var snapshot: NSImage?
    @Published var hasPiPCandidate: Bool = false
    @Published var isMuted: Bool = false

    private(set) var webView: WKWebView?
    private var lastSnapshotAt: Date = .distantPast
    private var isFetchingAssets = false

    private(set) var lastActivatedAt: Date
    private(set) var lastAccessed: Date

    private let assetsBaseURL: URL
    private let ownershipToken: String
    private var cancellables = Set<AnyCancellable>()

    private var assetsURLWithoutCreating: URL {
        assetsBaseURL
            .appendingPathComponent("TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "New Tab",
        favicon: NSImage? = nil,
        themeColor: Color? = nil,
        isLoading: Bool = false,
        hasMixedContentWarning: Bool = false,
        networkError: NetworkErrorKind? = nil,
        hoveredLinkURLString: String? = nil,
        assetsBaseURL: URL? = nil
    ) {
        self.id = id
        self.url = url
        if let url, let page = IlluminatePage(url: url), title == "New Tab" {
            self.title = page.tabTitle
        } else {
            self.title = title
        }
        self.favicon = favicon
        self.themeColor = themeColor
        self.isLoading = isLoading
        self.isHibernated = false
        self.hasMixedContentWarning = hasMixedContentWarning
        self.networkError = networkError
        self.hoveredLinkURLString = hoveredLinkURLString
        self.assetsBaseURL = assetsBaseURL ?? FileManager.default.illuminateAppSupportDirectory()
        self.ownershipToken = id.uuidString
        self.lastActivatedAt = Date()
        self.lastAccessed = Date()
    }

    convenience init(id: UUID, assetsBaseURL: URL? = nil) {
        let folder = (assetsBaseURL ?? FileManager.default.illuminateAppSupportDirectory())
            .appendingPathComponent("TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        
        let metaURL = folder.appendingPathComponent("metadata.json")
        var title = "New Tab"
        var url: URL? = nil
        
        if let data = try? Data(contentsOf: metaURL),
           let payload = try? JSONDecoder().decode(TabMetadataPayload.self, from: data) {
            title = payload.title ?? "New Tab"
            url = payload.url
        }
        
        self.init(
            id: id,
            url: url,
            title: title,
            assetsBaseURL: assetsBaseURL
        )
    }

    convenience init(payload: TabTransferPayload, assetsBaseURL: URL? = nil) {
        self.init(
            id: payload.id,
            url: payload.url,
            title: payload.title ?? "New Tab",
            assetsBaseURL: assetsBaseURL
        )
    }

    func markAccessed() {
        lastAccessed = Date()
    }

    func markActivated() {
        lastActivatedAt = Date()
    }

    func createWebViewIfNeeded(configuration: WKWebViewConfiguration, webKitManager: WebKitManager) {
        guard webView == nil else { return }

        let newWebView = IlluminateWebView(frame: .zero, configuration: configuration)
        newWebView.isInspectable = true
        newWebView.wantsLayer = true
        newWebView.pageZoom = zoomLevel
        webKitManager.applyBrowserUserAgent(to: newWebView)
        objc_setAssociatedObject(
            newWebView,
            &webViewTabOwnerKey,
            ownershipToken,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        webView = newWebView
        isHibernated = false
        setupWebViewObservers(newWebView)
    }

    func attachWebView(_ candidate: WKWebView) throws {
        if let owner = objc_getAssociatedObject(candidate, &webViewTabOwnerKey) as? String,
           owner != ownershipToken {
            throw TabError.webViewOwnershipConflict
        }
        objc_setAssociatedObject(
            candidate,
            &webViewTabOwnerKey,
            ownershipToken,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        candidate.pageZoom = zoomLevel
        webView = candidate
        isHibernated = false
        setupWebViewObservers(candidate)
    }

    func detachWebView() {
        cancellables.removeAll()
        webView = nil
        isLoading = false
        estimatedProgress = 0
        hasPiPCandidate = false
    }

    func close() {
        guard let webView else { return }

        let mediaShutdownScript = """
        (() => {
            try {
                if (document.pictureInPictureElement && document.exitPictureInPicture) {
                    document.exitPictureInPicture();
                }
            } catch {}

            for (const media of document.querySelectorAll('audio, video')) {
                try {
                    media.pause();
                    media.currentTime = 0;
                    media.srcObject = null;
                } catch {}
            }
        })();
        """

        webView.evaluateJavaScript(mediaShutdownScript, completionHandler: nil)
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
        hasPiPCandidate = false
        detachWebView()
    }

    func load(url: URL) {
        self.url = url
        if let page = IlluminatePage(url: url) {
            self.title = page.tabTitle
            return
        }
        webView?.load(URLRequest(url: url))
    }

    func reload() {
        if let webView {
            webView.reload()
        } else if let url {
            load(url: url)
        }
    }

    func refreshSnapshot() {
        guard let webView else { return }

        let now = Date()
        guard now.timeIntervalSince(lastSnapshotAt) > Self.snapshotMinInterval else { return }
        lastSnapshotAt = now

        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let image else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let downsampled = image.downsampled(toWidth: 400)
                self.saveAssets(snapshot: downsampled, favicon: self.favicon)
                self.snapshot = downsampled
            }
        }
    }

    func togglePictureInPicture() {
        guard let webView else { return }

        let script = """
        (function() {
            try {
                if (document.pictureInPictureElement) {
                    document.exitPictureInPicture();
                    return;
                }

                const videos = Array.from(document.querySelectorAll('video'))
                    .filter(v => v.readyState >= 2);
                if (videos.length === 0) return;

                const candidate =
                    videos.find(v => v === document.activeElement) || videos[0];

                if (candidate.requestPictureInPicture) {
                    candidate.requestPictureInPicture();
                }
            } catch (_) {}
        })();
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func toggleMute() {
        isMuted.toggle()
        guard let webView else { return }
        let muted = isMuted
        let script = """
        (() => {
            for (const media of document.querySelectorAll('audio, video')) {
                media.muted = \(muted ? "true" : "false");
            }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func zoomIn() {
        applyZoom((webView?.pageZoom ?? ZoomBounds.default) + ZoomBounds.step)
    }

    func zoomOut() {
        applyZoom((webView?.pageZoom ?? ZoomBounds.default) - ZoomBounds.step)
    }

    func resetZoom() {
        applyZoom(ZoomBounds.default)
    }

    private func applyZoom(_ newLevel: CGFloat) {
        guard let webView else { return }
        let clamped = min(max(newLevel, ZoomBounds.min), ZoomBounds.max)
        webView.pageZoom = clamped
        zoomLevel = clamped
        NotificationCenter.default.post(
            name: Self.zoomChangedNotification,
            object: nil,
            userInfo: [Self.zoomLevelKey: zoomLevel]
        )
    }

    func printPage() {
        guard let webView, let window = webView.window else { return }
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        let operation = webView.printOperation(with: printInfo)
        operation.view?.frame = webView.bounds
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    func openDevTools() {
        AppLog.info("Attempting to open Web Inspector for tab: \(url?.absoluteString ?? "nil")")
        guard let webView else { return }
        webView.isInspectable = true

        let inspectorSelector = NSSelectorFromString("_inspector")
        guard webView.responds(to: inspectorSelector),
              let inspector = webView.perform(inspectorSelector)?.takeUnretainedValue() as AnyObject? else {
            AppLog.info("Web Inspector unavailable for tab: \(url?.absoluteString ?? "nil")")
            return
        }

        let showSelector = NSSelectorFromString("show")
        guard inspector.responds(to: showSelector) else { return }
        _ = inspector.perform(showSelector)
    }

    private func saveAssets(snapshot: NSImage?, favicon: NSImage?) {
        let folder = assetsURLWithoutCreating
        let faviconData = favicon?.pngData()
        let snapshotData = snapshot?.jpegData(compressionQuality: 0.7)

        Task.detached(priority: .background) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let data = faviconData {
                try? data.write(to: folder.appendingPathComponent("favicon.png"))
            }
            if let data = snapshotData {
                try? data.write(to: folder.appendingPathComponent("snapshot.jpg"))
            }
        }
    }

    private func saveMetadata() {
        let payload = TabMetadataPayload(url: url, title: title)
        let folder = assetsURLWithoutCreating
        let encodedData = try? JSONEncoder().encode(payload)
        Task.detached(priority: .background) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let data = encodedData {
                try? data.write(to: folder.appendingPathComponent("metadata.json"), options: .atomic)
            }
        }
    }

    func loadAssets() {
        guard (favicon == nil || snapshot == nil), !isFetchingAssets else { return }
        isFetchingAssets = true
        let folder = assetsURLWithoutCreating

        Task.detached(priority: .utility) { [weak self] in
            let snapshotJPG = folder.appendingPathComponent("snapshot.jpg")
            let snapshotPNG = folder.appendingPathComponent("snapshot.png")

            let faviconData  = try? Data(contentsOf: folder.appendingPathComponent("favicon.png"))
            let snapshotData = (try? Data(contentsOf: snapshotJPG))
                            ?? (try? Data(contentsOf: snapshotPNG))

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isFetchingAssets = false
                if let data = faviconData  { self.favicon   = NSImage(data: data) }
                if let data = snapshotData { self.snapshot  = NSImage(data: data) }
            }
        }
    }

    func toTransferPayload() -> TabTransferPayload {
        TabTransferPayload(id: id, url: url, title: title)
    }

    private func setupWebViewObservers(_ webView: WKWebView) {
        cancellables.removeAll()

        webView.publisher(for: \.canGoBack)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.canGoBack = v }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoForward)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.canGoForward = v }
            .store(in: &cancellables)

        webView.publisher(for: \.estimatedProgress)
            .removeDuplicates()
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] v in self?.estimatedProgress = v }
            .store(in: &cancellables)

        webView.publisher(for: \.isLoading)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                guard let self else { return }
                self.isLoading = v
                if !v, self.isMuted {
                    let script = """
                    (() => {
                        for (const media of document.querySelectorAll('audio, video')) {
                            media.muted = true;
                        }
                    })();
                    """
                    self.webView?.evaluateJavaScript(script, completionHandler: nil)
                }
            }
            .store(in: &cancellables)

        webView.publisher(for: \.url)
            .removeDuplicates()
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] v in
                guard let self, let url = v, self.url != url else { return }
                self.url = url
            }
            .store(in: &cancellables)

        webView.publisher(for: \.title)
            .removeDuplicates()
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] v in
                guard let self, let title = v, !title.isEmpty, self.title != title else { return }
                self.title = title
            }
            .store(in: &cancellables)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.canGoBack         != webView.canGoBack         { self.canGoBack         = webView.canGoBack }
            if self.canGoForward      != webView.canGoForward      { self.canGoForward      = webView.canGoForward }
            if self.estimatedProgress != webView.estimatedProgress { self.estimatedProgress = webView.estimatedProgress }
            if self.isLoading         != webView.isLoading         { self.isLoading         = webView.isLoading }
            if let currentURL = webView.url, self.url != currentURL { self.url = currentURL }
        }
    }
}