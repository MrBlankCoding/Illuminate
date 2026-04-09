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

// ownership
// rust mention?
private var webViewTabOwnerKey: UInt8 = 0

final class IlluminateWebView: WKWebView {
    var onIlluminateDownload: ((NSEvent) -> Void)?

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

    // important...
    // or is it
    let id: UUID

    @Published var url: URL?
    @Published var title: String {
        didSet { onMetadataUpdate?() }
    }
    @Published var favicon: NSImage? {
        didSet { onMetadataUpdate?() }
    }
    @Published var themeColor: Color?
    @Published var isLoading: Bool
    @Published var isHibernated: Bool
    @Published var hasMixedContentWarning: Bool
    @Published var lastNavigationHadNetworkError: Bool
    @Published var lastNetworkErrorMessage: String?
    @Published var isDNSError: Bool = false
    @Published var hoveredLinkURLString: String?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var groupID: UUID?
    @Published var zoomLevel: Double = 1.0
    @Published var snapshot: NSImage?
    @Published var hasPiPCandidate: Bool = false

    private(set) var webView: WKWebView?
    private var lastSnapshotAt: Date = .distantPast
    private var isFetchingAssets = false

    var onMetadataUpdate: (() -> Void)?
    private(set) var lastActivatedAt: Date
    private(set) var lastAccessed: Date

    private let ownershipToken: String
    private var cancellables = Set<AnyCancellable>()
    private var assetsURL: URL {
        makeAssetsURL(createIfNeeded: true)
    }

    // Returns the on-disk assets URL without creating the directory.
    // Use only for path
    private var assetsURLWithoutCreating: URL {
        makeAssetsURL(createIfNeeded: false)
    }

    private func makeAssetsURL(createIfNeeded: Bool) -> URL {
        let base = FileManager.default
            .illuminateAppSupportDirectory()
            .appendingPathComponent("TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if createIfNeeded {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "New Tab",
        favicon: NSImage? = nil,
        themeColor: Color? = nil,
        isLoading: Bool = false,
        hasMixedContentWarning: Bool = false,
        lastNavigationHadNetworkError: Bool = false,
        lastNetworkErrorMessage: String? = nil,
        hoveredLinkURLString: String? = nil,
        groupID: UUID? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.favicon = favicon
        self.themeColor = themeColor
        self.isLoading = isLoading
        self.isHibernated = false
        self.hasMixedContentWarning = hasMixedContentWarning
        self.lastNavigationHadNetworkError = lastNavigationHadNetworkError
        self.lastNetworkErrorMessage = lastNetworkErrorMessage
        self.hoveredLinkURLString = hoveredLinkURLString
        self.groupID = groupID
        self.ownershipToken = id.uuidString
        self.lastActivatedAt = Date()
        self.lastAccessed = Date()
    }

    convenience init(payload: TabTransferPayload) {
        self.init(
            id: payload.id,
            url: payload.url,
            title: payload.title ?? "New Tab",
            groupID: payload.groupID
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
        webKitManager.applySafariUserAgent(to: newWebView)
        objc_setAssociatedObject(
            newWebView,
            &webViewTabOwnerKey,
            ownershipToken,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        webView = newWebView
        Task { @MainActor [weak self] in
            self?.isHibernated = false
        }
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
        webView = candidate
        isHibernated = false
        setupWebViewObservers(candidate)
    }

    func detachWebView() {
        cancellables.removeAll()
        webView = nil
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
        guard url.scheme != "illuminate" else { return }
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
            guard let self, let image else { return }
            let downsampled = image.downsampled(toWidth: 400)
            let favicon = self.favicon
            self.saveAssets(snapshot: downsampled, favicon: favicon)
            Task { @MainActor [weak self] in
                self?.snapshot = downsampled
            }
        }
    }

    // this needs to be fixed
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

    // still glitchy
    func openDevTools() {
        AppLog.info("Attempting to open Web Inspector for tab: \(url?.absoluteString ?? "nil")")
        guard let webView else { return }
        webView.isInspectable = true

        if let inspector = webView
            .perform(NSSelectorFromString("_inspector"))?
            .takeUnretainedValue() as AnyObject? {
            _ = inspector.perform(NSSelectorFromString("show"))
        }
    }

    private func saveAssets(snapshot: NSImage?, favicon: NSImage?) {
        let folder = assetsURL
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

    func loadAssets() {
        guard (favicon == nil || snapshot == nil), !isFetchingAssets else { return }
        isFetchingAssets = true
        let folder = assetsURL

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
        TabTransferPayload(id: id, url: url, title: title, groupID: groupID)
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
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.estimatedProgress = v }
            .store(in: &cancellables)

        webView.publisher(for: \.isLoading)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.isLoading = v }
            .store(in: &cancellables)

        webView.publisher(for: \.url)
            .removeDuplicates()
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                guard let url = v else { return }
                if self?.url != url { self?.url = url }
            }
            .store(in: &cancellables)

        webView.publisher(for: \.title)
            .removeDuplicates()
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                guard let title = v, !title.isEmpty else { return }
                if self?.title != title { self?.title = title }
            }
            .store(in: &cancellables)

        // Seed initial values outside the current view-update cycle.
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