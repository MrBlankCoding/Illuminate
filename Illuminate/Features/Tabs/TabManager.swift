//
//
//  TabManager.swift
//  Illuminate
//
//
//  Created by MrBlankCoding on 4/8/26.
//

import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit


@MainActor
final class TabManager: NSObject, ObservableObject, WKWebExtensionWindow {

    var windowState: WKWebExtension.WindowState {
        if isFullScreen { return .fullscreen }
        return .normal
    }

    var windowType: WKWebExtension.WindowType {
        .normal
    }

    var isPrivate: Bool {
        activeProfileID == nil // Assuming nil profile ID means guest/private
    }

    weak var window: NSWindow?

    var isFocused: Bool {
        window?.isKeyWindow ?? false
    }

    func focus(completionHandler: @escaping ((any Error)?) -> Void) {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        completionHandler(nil)
    }

    enum Defaults {
        static let themeColor        = "808080"
        static let maxRecentlyClosed = 25
        static let saveDebounceNs: UInt64 = 500_000_000
        static let tabCreationDelay: TimeInterval = 0.05
        static let rapidSwitchDebounceNs: UInt64 = 1_000_000_000
    }

    @Published var tabs: [Tab] = []
    @Published var activeTabID: UUID?
    @Published var isResizing: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var backgroundImagePalette: [Color] = []
    @Published private var initialPreloadingTabIDs: Set<UUID> = []
    let tabGroupManager: TabGroupManager

    @Published var theme: IlluminateTheme {
        didSet {
            guard isPersistenceEnabled, !isInitializing else { return }
            if let data = try? JSONEncoder().encode(theme),
               let json = String(data: data, encoding: .utf8) {
                persistIfEnabled(json, forKey: "browserTheme")
            }
            // Sync legacy properties for backward compatibility
            if let firstColor = theme.colors.first?.color {
                windowThemeColor = firstColor
            }
            userInterfaceStyle = theme.colorScheme.toUIStyle()
        }
    }

    @Published var windowThemeColor: Color {
        didSet {
            if let hex = windowThemeColor.toHex() {
                persistIfEnabled(hex, forKey: "windowThemeColor")
            }
        }
    }

    @Published var backgroundImageURL: String {
        didSet {
            guard isPersistenceEnabled, !isInitializing else { return }
            persistIfEnabled(backgroundImageURL, forKey: "backgroundImageURL")
            updateThemeFromBackground(applyTheme: true)
        }
    }

    @Published var showSidebar: Bool {
        didSet { persistIfEnabled(showSidebar, forKey: "showSidebar") }
    }

    @Published var showBackgroundBehindSidebar: Bool {
        didSet { persistIfEnabled(showBackgroundBehindSidebar, forKey: "showBackgroundBehindSidebar") }
    }

    @Published var userInterfaceStyle: UIStyle {
        didSet { persistIfEnabled(userInterfaceStyle.rawValue, forKey: "userInterfaceStyle") }
    }


    var activeTab: Tab? {
        guard let activeTabID else { return nil }
        return tabIndex[activeTabID]
    }

    func shouldSuppressLoadingIndicator(for tab: Tab) -> Bool {
        initialPreloadingTabIDs.contains(tab.id)
    }

    func beginInitialTabPreloadingSuppression(for tabs: [Tab]) {
        initialPreloadingTabIDs = Set(tabs.map(\.id))
    }

    func finishInitialTabPreloading(for tabID: UUID) {
        guard initialPreloadingTabIDs.contains(tabID) else { return }
        initialPreloadingTabIDs.remove(tabID)
    }

    var canReopenTab: Bool { !recentlyClosed.isEmpty }

    let notificationCenter: NotificationCenter
    let urlSynchronizer: URLSynchronizer
    let userDefaults: UserDefaults
    let isPersistenceEnabled: Bool
    let sessionURL: URL
    let faviconCache: FaviconCache
    let sessionWriter = SessionWriter()
    // not private ahh!
    let extensionManager: ExtensionManager

    var activeProfileID: UUID?
    var profileID: UUID? { activeProfileID }
    var tabIndex: [UUID: Tab] = [:]
    private var tabPositionIndex: [UUID: Int] = [:]

    private struct ClosedTabSnapshot {
        let payload: TabTransferPayload
    }

    private var recentlyClosed: [ClosedTabSnapshot] = []
    private var isInitializing = true
    var pristineBlankTabID: UUID?
    var pendingSaveTask: Task<Void, Never>?
    var backgroundThemeTask: Task<Void, Never>?
    private var pendingFocusTask: Task<Void, Never>?
    var saveVersion: UInt64 = 0
    var observerTokens: [NSObjectProtocol] = []
    var extensionObserverCancellable: AnyCancellable?
    var lastReloadedExtensionIDs: [String] = []
    var lastSwitchTime: Date?

    enum UIStyle: String, CaseIterable {
        case dark, light, system

        var colorScheme: ColorScheme? {
            switch self {
            case .dark:   return .dark
            case .light:  return .light
            case .system: return nil
            }
        }
    }

    @MainActor
    init(
        profileID: UUID? = nil,
        notificationCenter: NotificationCenter = .default,
        urlSynchronizer: URLSynchronizer,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true,
        faviconCache: FaviconCache? = nil,
        extensionManager: ExtensionManager? = nil
    ) {
        let resolvedExtensionManager = extensionManager ?? ExtensionManager(profileID: profileID)
        self.activeProfileID    = profileID
        self.notificationCenter = notificationCenter
        self.urlSynchronizer    = urlSynchronizer
        self.userDefaults       = userDefaults
        self.isPersistenceEnabled = isPersistenceEnabled
        self.faviconCache       = faviconCache ?? .shared
        self.sessionURL         = Self.makeSessionURL(profileID: profileID)
        self.tabGroupManager    = TabGroupManager(profileID: profileID, isPersistenceEnabled: isPersistenceEnabled)
        self.extensionManager   = resolvedExtensionManager

        let savedHex = isPersistenceEnabled
            ? (userDefaults.string(forKey: Self.scopedKey("windowThemeColor", profileID: profileID)) ?? Defaults.themeColor)
            : Defaults.themeColor
        self.windowThemeColor = Color(hex: savedHex)

        self.backgroundImageURL = isPersistenceEnabled
            ? (userDefaults.string(forKey: Self.scopedKey("backgroundImageURL", profileID: profileID)) ?? "")
            : ""

        self.showSidebar = isPersistenceEnabled
            ? userDefaults.bool(forKey: Self.scopedKey("showSidebar", profileID: profileID), default: true)
            : true

        self.showBackgroundBehindSidebar = isPersistenceEnabled
            ? userDefaults.bool(forKey: Self.scopedKey("showBackgroundBehindSidebar", profileID: profileID), default: true)
            : true

        let savedStyle = isPersistenceEnabled
            ? (userDefaults.string(forKey: Self.scopedKey("userInterfaceStyle", profileID: profileID)) ?? "dark")
            : "dark"
        let style = UIStyle(rawValue: savedStyle) ?? .dark
        self.userInterfaceStyle = style

        if isPersistenceEnabled,
           let themeJSON = userDefaults.string(forKey: Self.scopedKey("browserTheme", profileID: profileID)),
           let themeData = themeJSON.data(using: .utf8),
           let savedTheme = try? JSONDecoder().decode(IlluminateTheme.self, from: themeData) {
            self.theme = savedTheme
        } else {
            var defaultTheme = IlluminateTheme.default
            defaultTheme.colorScheme = ThemeScheme.fromUIStyle(style)
            
            // Start with a neutral grey theme if no image is present
            let grey = Color(hex: Defaults.themeColor).resolvedHSL
            if let firstIdx = defaultTheme.colors.indices.first {
                defaultTheme.colors[firstIdx].hue = grey.h
                defaultTheme.colors[firstIdx].saturation = grey.s
                defaultTheme.colors[firstIdx].lightness = grey.l
                defaultTheme.colors[firstIdx].position = ThemeColorMath.colorToPoint(hue: grey.h, saturation: grey.s)
            }
            
            self.theme = defaultTheme
        }

        super.init()

        if isPersistenceEnabled {
            ensureWebExtensionsDirectoryExists()
        }

        if isPersistenceEnabled {
            restoreSession()
        }

        hydrateRestoredTabs()
        ensureValidActiveTabSelection(persist: false)
        setupObservers()

        if tabs.isEmpty {
            pristineBlankTabID = createTab().id
        }

        resolvedExtensionManager.registerTabManager(self)

        Task { @MainActor [weak self] in
            self?.isInitializing = false
            self?.updateThemeFromBackground(applyTheme: false)
        }
    }

    @MainActor
    convenience init(
        profile: BrowserProfile,
        notificationCenter: NotificationCenter = .default,
        urlSynchronizer: URLSynchronizer,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true
    ) {
        self.init(
            profileID: profile.id,
            notificationCenter: notificationCenter,
            urlSynchronizer: urlSynchronizer,
            userDefaults: userDefaults,
            isPersistenceEnabled: isPersistenceEnabled
        )
    }

    @MainActor
    convenience init(isPersistenceEnabled: Bool = true) {
        self.init(
            profileID: nil,
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: isPersistenceEnabled
        )
    }

    deinit {
        let identifier = ObjectIdentifier(self)
        let em = extensionManager
        DispatchQueue.main.async {
            em.unregisterTabManager(withIdentifier: identifier)
        }
        observerTokens.forEach { notificationCenter.removeObserver($0) }
        extensionObserverCancellable?.cancel()
        pendingSaveTask?.cancel()
        backgroundThemeTask?.cancel()
        pendingFocusTask?.cancel()
    }


    var tabAssetsBaseURL: URL {
        activeProfileID.map {
            FileManager.default.illuminateProfileDirectory(profileID: $0)
        } ?? FileManager.default.illuminateAppSupportDirectory()
    }


    func rebuildTabIndex() {
        tabIndex = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        tabPositionIndex = Dictionary(uniqueKeysWithValues: tabs.enumerated().map { ($1.id, $0) })
    }

    private func indexTab(_ tab: Tab) {
        tabIndex[tab.id] = tab
        tabPositionIndex[tab.id] = tabs.firstIndex(where: { $0.id == tab.id }) ?? (tabs.count - 1)
    }

    private func deindexTab(id: UUID) {
        tabIndex.removeValue(forKey: id)
        let removedPos = tabPositionIndex.removeValue(forKey: id)
        if let removed = removedPos {
            for (tid, pos) in tabPositionIndex where pos > removed {
                tabPositionIndex[tid] = pos - 1
            }
        }
    }

    func prepareForRemoval() {
        observerTokens.forEach { notificationCenter.removeObserver($0) }
        observerTokens.removeAll()
        pendingSaveTask?.cancel()
        backgroundThemeTask?.cancel()
        pendingFocusTask?.cancel()
        tabGroupManager.prepareForRemoval()
        clearAllTabs()
    }

    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        tabs
    }

    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        activeTab
    }

    // okay im pulling my hair out
    func tab(forID id: UUID) -> Tab? { tabIndex[id] }
    func indexOfTab(withID id: UUID) -> Int? { tabPositionIndex[id] }

    func makeTab(from payload: TabTransferPayload) -> Tab {
        let tab = Tab(payload: payload, assetsBaseURL: tabAssetsBaseURL)
        return tab
    }

    // over engineered
    // TODO:
    func navigateActiveTab(to url: URL) {
        if url.scheme == "webkit-extension" {
            createTab(url: url)
            return
        }

        if let tab = activeTab {
            tab.load(url: url)
        } else {
            createTab(url: url)
        }
    }

    // keep it simple
    func ensureHasAtLeastOneTab() {
        if tabs.isEmpty { createTab() }
    }

    func consumePristineBlankTabForExternalOpen() -> UUID? {
        guard let id = pristineBlankTabID, tabIndex[id]?.url == nil else {
            pristineBlankTabID = nil
            return nil
        }
        pristineBlankTabID = nil
        return id
    }

    @discardableResult
    func createTab(url: URL? = nil, inBackground: Bool = false, configuration: WKWebViewConfiguration? = nil) -> Tab {
        var finalConfiguration = configuration

        if let url = url, url.scheme == "webkit-extension", configuration == nil {
            if let extensionContext = extensionManager.getExtensionContext(for: url) {
                finalConfiguration = extensionContext.webViewConfiguration
            }
        }

        let tab = Tab(url: url, assetsBaseURL: tabAssetsBaseURL, webViewConfiguration: finalConfiguration)
        tab.tabManager = self

        tabs.append(tab)
        tabIndex[tab.id] = tab
        tabPositionIndex[tab.id] = tabs.count - 1
        hydrateVisualState(for: tab)

        extensionManager.controller.didOpenTab(tab)

        if !inBackground {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                switchTo(tab.id)
            }
        }

        if !inBackground {
            pendingFocusTask?.cancel()
            pendingFocusTask = Task { [weak self, notificationCenter] in
                try? await Task.sleep(nanoseconds: UInt64(Defaults.tabCreationDelay * 1_000_000_000))
                guard !Task.isCancelled, self != nil else { return }
                notificationCenter.post(name: .focusURLBar, object: nil)
            }
        }

        scheduleSave()
        updateProtectedFaviconURLs()

        return tab
    }

    func closeTab(id: UUID) {
        guard let index = tabPositionIndex[id] ?? tabs.firstIndex(where: { $0.id == id }) else { return }

        let tab = tabs[index]
        let payload = tab.toTransferPayload()
        tab.close()
        pushRecentlyClosed(payload)
        tabGroupManager.handleTabClosed(id)
        extensionManager.controller.didCloseTab(tab, windowIsClosing: false)

        tabs.remove(at: index)
        deindexTab(id: id)
        removeTabAssets(for: id)
        updateProtectedFaviconURLs()

        if activeTabID == id {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let nextID = (tabs[safe: index] ?? tabs.last)?.id
                activeTabID = nextID
                syncActiveTabURL()
            }
        }

        if tabs.isEmpty {
            NSApp.keyWindow?.performClose(nil)
        }

        scheduleSave()
    }

    func closeActiveTab() {
        guard let activeTabID else { return }
        closeTab(id: activeTabID)
    }

    func clearAllTabs() {
        tabs.forEach {
            let payload = $0.toTransferPayload()
            $0.close()
            pushRecentlyClosed(payload)
            removeTabAssets(for: $0.id)
        }
        tabs.removeAll()
        tabIndex.removeAll()
        tabPositionIndex.removeAll()
        activeTabID = nil
        syncActiveTabURL()
        scheduleSave()
    }

    @discardableResult
    func reopenLastClosedTab() -> Tab? {
        guard let snapshot = recentlyClosed.popLast() else { return nil }
        let tab = makeTab(from: snapshot.payload)
        tab.tabManager = self

        tabs.append(tab)
        tabIndex[tab.id] = tab
        tabPositionIndex[tab.id] = tabs.count - 1
        hydrateVisualState(for: tab)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switchTo(tab.id)
        }
        scheduleSave()
        return tab
    }

    func moveTab(fromOffsets: IndexSet, toOffset: Int) {
        tabs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (i, t) in tabs.enumerated() { tabPositionIndex[t.id] = i }
        tabGroupManager.handleTabsReordered(tabs.map { $0.id })
        scheduleSave()
    }

    func nextTab()     { cycleTab(by: +1) }
    func previousTab() { cycleTab(by: -1) }

    func switchToMostRecentTab() {
        guard let activeTabID else { return }
        guard let mostRecentTab = tabs
            .filter({ $0.id != activeTabID })
            .max(by: { $0.lastActivatedAt < $1.lastActivatedAt })
        else { return }

        switchTo(mostRecentTab.id)
    }

    func switchTo(_ id: UUID) {
        guard activeTabID != id else { return }

        lastSwitchTime = Date()
        setActiveTab(id)
    }

    func setActiveTab(_ id: UUID?) {
        let oldTab = activeTab
        activeTabID = id
        if let id, let tab = tabIndex[id] {
            finishInitialTabPreloading(for: id)
            tab.markActivated()
            tab.markAccessed()

            extensionManager.controller.didActivateTab(tab, previousActiveTab: oldTab)
        }
        syncActiveTabURL()
        guard isPersistenceEnabled, !isInitializing else { return }
        scheduleSave()
    }

    func updateTabURL(tabID: UUID, url: URL?) {
        guard let tab = tabIndex[tabID] else { return }
        tab.url     = url
        tab.favicon = nil
        hydrateVisualState(for: tab)
        if tabID == activeTabID { syncActiveTabURL() }
        scheduleSave()
    }

    func syncActiveTabURL() {
        urlSynchronizer.updateCurrentURL(activeTab?.url)
    }

    func updateProtectedFaviconURLs() {
        faviconCache.setProtectedURLs(tabs.filter(\.isPinned).compactMap(\.url))
    }

    private func cycleTab(by delta: Int) {
        guard
            let currentID = activeTabID,
            let index = tabPositionIndex[currentID] ?? tabs.firstIndex(where: { $0.id == currentID }),
            tabs.count > 1
        else { return }

        let nextIndex = (index + delta + tabs.count) % tabs.count
        lastSwitchTime = Date()
        switchTo(tabs[nextIndex].id)
    }

    private func ensureValidActiveTabSelection(persist: Bool = true) {
        guard !tabs.isEmpty else { return }
        guard let id = activeTabID, tabIndex[id] != nil else {
            let first = tabs[0]
            activeTabID = first.id
            first.markActivated()
            first.markAccessed()
            syncActiveTabURL()
            if persist { scheduleSave() }
            return
        }
    }

    private func pushRecentlyClosed(_ payload: TabTransferPayload) {
        recentlyClosed.append(ClosedTabSnapshot(payload: payload))
        if recentlyClosed.count > Defaults.maxRecentlyClosed {
            recentlyClosed.removeFirst()
        }
    }


    func saveActiveTabAsPDF() {
        // If the active tab is showing a PDF in the viewer, offer to save the
        // original file with a save panel so the user can choose the destination.
        if let sourceURL = activeTab?.url,
           let page = IlluminatePage(url: sourceURL),
           let pdfFileURL = page.pdfSourceFileURL(from: sourceURL) {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = pdfFileURL.lastPathComponent
            panel.directoryURL = pdfFileURL.deletingLastPathComponent()
            panel.allowedContentTypes = [.pdf]
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            do {
                if pdfFileURL != destination {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: pdfFileURL, to: destination)
                }
            } catch {
                AppLog.error("[TabManager] Failed to save PDF", error: error)
            }
            return
        }

        guard
            let webView = activeTab?.webView,
            let sourceURL = activeTab?.url
        else {
            AppLog.info("[TabManager] Save as PDF requested with no active web view.")
            return
        }

        let title = activeTab?.title ?? ""
        let baseName = (!title.isEmpty ? title : (sourceURL.host ?? "page"))
            .replacingOccurrences(of: "/", with: "-")
        let filename = baseName.hasSuffix(".pdf") ? baseName : "\(baseName).pdf"

        let configuration = WKPDFConfiguration()

        let js = """
        (() => {
            const doc = document.documentElement;
            const body = document.body;
            const w = Math.max(
                doc ? doc.scrollWidth : 0,
                doc ? doc.offsetWidth : 0,
                doc ? doc.clientWidth : 0,
                body ? body.scrollWidth : 0,
                body ? body.offsetWidth : 0,
                body ? body.clientWidth : 0
            );
            const h = Math.max(
                doc ? doc.scrollHeight : 0,
                doc ? doc.offsetHeight : 0,
                doc ? doc.clientHeight : 0,
                body ? body.scrollHeight : 0,
                body ? body.offsetHeight : 0,
                body ? body.clientHeight : 0
            );
            return { w: w, h: h };
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            if let dict = result as? [String: Any],
               let wNumber = dict["w"] as? NSNumber,
               let hNumber = dict["h"] as? NSNumber {
                let w = CGFloat(wNumber.doubleValue)
                let h = CGFloat(hNumber.doubleValue)
                if w > 0 && h > 0 {
                    configuration.rect = CGRect(x: 0, y: 0, width: w, height: h)
                }
            } else if let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let wNumber = obj["w"] as? NSNumber,
                      let hNumber = obj["h"] as? NSNumber {
                let w = CGFloat(wNumber.doubleValue)
                let h = CGFloat(hNumber.doubleValue)
                if w > 0 && h > 0 {
                    configuration.rect = CGRect(x: 0, y: 0, width: w, height: h)
                }
            }
            webView.createPDF(configuration: configuration) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let data):
                    DownloadManager.shared.saveDownloadedData(
                        data,
                        from: sourceURL,
                        suggestedFilename: filename,
                        mimeType: "application/pdf",
                        profileID: self.activeProfileID
                    )
                case .failure(let error):
                    AppLog.error("[TabManager] PDF failed to create", error: error)
                }
            }
        }
    }

    func moveActiveTabToAdjacentGroup(direction: Int) {
        guard let activeTabID else { return }
        let groups = tabGroupManager.groups
        guard !groups.isEmpty else { return }

        if let currentGroup = tabGroupManager.group(for: activeTabID) {
            guard let groupIdx = tabGroupManager.position(ofGroup: currentGroup.id) else { return }
            let targetIdx = groupIdx + direction
            if groups.indices.contains(targetIdx) {
                tabGroupManager.moveTabToGroup(activeTabID, targetGroupID: groups[targetIdx].id)
            } else {
                tabGroupManager.removeTabFromGroup(activeTabID)
            }
        } else {
            guard let tabIdx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }

            if direction > 0 {
                for i in (tabIdx + 1)..<tabs.count {
                    if let group = tabGroupManager.group(for: tabs[i].id) {
                        tabGroupManager.addTabToGroup(activeTabID, groupID: group.id)
                        return
                    }
                }
            } else {
                for i in stride(from: tabIdx - 1, through: 0, by: -1) {
                    if let group = tabGroupManager.group(for: tabs[i].id) {
                        tabGroupManager.addTabToGroup(activeTabID, groupID: group.id)
                        return
                    }
                }
            }
        }
    }

    private func ensureWebExtensionsDirectoryExists() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.MrBlankCoding.Illuminate"
        let containerLibraryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(bundleID)/Data/Library")
        let webExtensionsURL = containerLibraryURL.appendingPathComponent("WebKit/WebExtensions")

        do {
            try FileManager.default.createDirectory(at: webExtensionsURL, withIntermediateDirectories: true, attributes: nil)
            AppLog.debug("[TabManager] WebExtensions directory ensured at: \(webExtensionsURL.path)")
        } catch {
            AppLog.error("[TabManager] Failed to create WebExtensions directory", error: error)
        }
    }
}
