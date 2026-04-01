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

private var webViewTabOwnerKey: UInt8 = 0

@MainActor
final class Tab: ObservableObject, Identifiable {

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
    private var observers: [NSKeyValueObservation] = []
    private var cancellables = Set<AnyCancellable>()

    private var assetsURL: URL {
        let base = FileManager.default
            .illuminateAppSupportDirectory()
            .appendingPathComponent("TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
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

        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        newWebView.isInspectable = true
        webKitManager.applySafariUserAgent(to: newWebView)
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
        webView = candidate
        isHibernated = false
        setupWebViewObservers(candidate)
    }

    func detachWebView() {
        observers.removeAll()
        cancellables.removeAll()
        webView = nil
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
        guard now.timeIntervalSince(lastSnapshotAt) > 10 else { return } // Max once every 10s
        lastSnapshotAt = now
        
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self = self, let image = image else { return }
            let downsampled = image.downsampled(toWidth: 400)
            let favicon = self.favicon
            self.saveAssets(snapshot: downsampled, favicon: favicon)
            Task { @MainActor [weak self] in
                guard let self else { return }
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

                const videos = Array.from(document.querySelectorAll('video')).filter(v => v.readyState >= 2);
                if (videos.length === 0) {
                    return;
                }

                const candidate = videos.find(v => v === document.activeElement) || videos[0];

                if (candidate.requestPictureInPicture) {
                    candidate.requestPictureInPicture();
                }
            } catch (e) {
                // swallow
            }
        })();
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
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
            
            let faviconData = try? Data(contentsOf: folder.appendingPathComponent("favicon.png"))
            let snapshotData = (try? Data(contentsOf: snapshotJPG)) ?? (try? Data(contentsOf: snapshotPNG))

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isFetchingAssets = false
                if let data = faviconData  { self.favicon   = NSImage(data: data) }
                if let data = snapshotData { self.snapshot  = NSImage(data: data) }
            }
        }
    }

    func toTransferPayload() -> TabTransferPayload {
        return TabTransferPayload(
            id: id,
            url: url,
            title: title,
            groupID: groupID
        )
    }

    func zoomIn() {
        guard let webView else { return }
        webView.pageZoom += 0.1
        zoomLevel = Double(webView.pageZoom)
        NotificationCenter.default.post(name: NSNotification.Name("app.zoomChanged"), object: nil, userInfo: ["level": zoomLevel])
    }

    func zoomOut() {
        guard let webView else { return }
        webView.pageZoom = max(0.1, webView.pageZoom - 0.1)
        zoomLevel = Double(webView.pageZoom)
        NotificationCenter.default.post(name: NSNotification.Name("app.zoomChanged"), object: nil, userInfo: ["level": zoomLevel])
    }

    func resetZoom() {
        guard let webView else { return }
        webView.pageZoom = 1.0
        zoomLevel = 1.0
        NotificationCenter.default.post(name: NSNotification.Name("app.zoomChanged"), object: nil, userInfo: ["level": zoomLevel])
    }

    // why was this so annoying
    // apple why are you like this sometimes
    func openDevTools() {
        AppLog.info("Attempting to open Web Inspector for tab with URL: \(url?.absoluteString ?? "nil")")
        guard let webView else { return }

        webView.isInspectable = true

        if let inspector = webView.perform(NSSelectorFromString("_inspector"))?.takeUnretainedValue() as AnyObject? {
            _ = inspector.perform(NSSelectorFromString("show"))
        }
    }

    private func setupWebViewObservers(_ webView: WKWebView) {
        observers.removeAll()
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

        // Seed initial values safely outside the current view update cycle
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.canGoBack        != webView.canGoBack        { self.canGoBack        = webView.canGoBack }
            if self.canGoForward     != webView.canGoForward     { self.canGoForward     = webView.canGoForward }
            if self.estimatedProgress != webView.estimatedProgress { self.estimatedProgress = webView.estimatedProgress }
            if let currentURL = webView.url, self.url != currentURL { self.url = currentURL }
        }
    }
}
