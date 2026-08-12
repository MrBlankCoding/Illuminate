//
//  TabManager.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/8/26.
//

import Combine
import Foundation
import OSLog
import SwiftUI
import WebKit


struct ClosedTabSnapshot {
    let payload: TabTransferPayload
}

private actor SessionWriter {
    private var latestVersion: UInt64 = 0

    func write(data: Data, version: UInt64, to url: URL, logger: Logger) async {
        guard version >= latestVersion else { return }
        latestVersion = version
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("[TabManager] Session write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}


@MainActor
final class TabManager: ObservableObject {
    private enum Defaults {
        static let themeColor        = "89BBFF"
        static let maxRecentlyClosed = 25
        static let saveDebounceNs: UInt64 = 500_000_000
        static let tabCreationDelay: TimeInterval = 0.1
    }

    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var activeTabID: UUID?
    @Published var isResizing: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var backgroundImagePalette: [Color] = []
    let tabGroupManager: TabGroupManager

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

    @Published var bookmarkBarVisibility: BookmarkBarVisibility {
        didSet { persistIfEnabled(bookmarkBarVisibility.rawValue, forKey: "bookmarkBarVisibility") }
    }

    var activeTab: Tab? {
        guard let activeTabID else { return nil }
        return tabIndex[activeTabID]
    }

    var canReopenTab: Bool { !recentlyClosed.isEmpty }

    private let notificationCenter: NotificationCenter
    private let urlSynchronizer: URLSynchronizer
    private let userDefaults: UserDefaults
    private let isPersistenceEnabled: Bool
    private let sessionURL: URL
    private let faviconCache: FaviconCache
    private let sessionWriter = SessionWriter()
    private let logger = Logger(subsystem: "com.illuminate", category: "TabManager")

    private var activeProfileID: UUID?

    // O(1) tab access by ID; kept in sync with the `tabs` array.
    private var tabIndex: [UUID: Tab] = [:]

    private var recentlyClosed: [ClosedTabSnapshot] = []
    private var isInitializing = true
    private var pendingSaveTask: Task<Void, Never>?
    private var backgroundThemeTask: Task<Void, Never>?
    private var pendingFocusTask: Task<Void, Never>?
    private var saveVersion: UInt64 = 0
    private var observerTokens: [NSObjectProtocol] = []

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
        faviconCache: FaviconCache? = nil
    ) {
        self.activeProfileID    = profileID
        self.notificationCenter = notificationCenter
        self.urlSynchronizer    = urlSynchronizer
        self.userDefaults       = userDefaults
        self.isPersistenceEnabled = isPersistenceEnabled
        self.faviconCache       = faviconCache ?? .shared
        self.sessionURL         = Self.makeSessionURL(profileID: profileID)
        self.tabGroupManager    = TabGroupManager(profileID: profileID, isPersistenceEnabled: isPersistenceEnabled)

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
        self.userInterfaceStyle = UIStyle(rawValue: savedStyle) ?? .dark

        let savedBarVisibility = isPersistenceEnabled
            ? (userDefaults.string(forKey: Self.scopedKey("bookmarkBarVisibility", profileID: profileID)) ?? BookmarkBarVisibility.always.rawValue)
            : BookmarkBarVisibility.always.rawValue
        self.bookmarkBarVisibility = BookmarkBarVisibility(rawValue: savedBarVisibility) ?? .always

        if isPersistenceEnabled {
            restoreSession()
        }

        hydrateRestoredTabs()
        ensureValidActiveTabSelection(persist: false)
        setupObservers()

        if tabs.isEmpty {
            createTab()
        }

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
        observerTokens.forEach { notificationCenter.removeObserver($0) }
        pendingSaveTask?.cancel()
        backgroundThemeTask?.cancel()
        pendingFocusTask?.cancel()
    }

    private static func makeSessionURL(profileID: UUID?) -> URL {
        let base: URL = profileID.map {
            FileManager.default.illuminateProfileDirectory(profileID: $0)
        } ?? FileManager.default.illuminateAppSupportDirectory()
        return base.appendingPathComponent("session.json")
    }

    private var tabAssetsBaseURL: URL {
        activeProfileID.map {
            FileManager.default.illuminateProfileDirectory(profileID: $0)
        } ?? FileManager.default.illuminateAppSupportDirectory()
    }

    private func restoreSession() {
        switch loadSessionState() {
        case .success(let state):
            activeTabID = state.activeTabID
            if let ids = state.tabIDs {
                tabs = ids.map { Tab(id: $0, assetsBaseURL: tabAssetsBaseURL) }
            } else if let payloads = state.tabs {
                tabs = payloads.map { makeTab(from: $0) }
            }
            rebuildTabIndex()
        case .failure(let error):
            let nsError = error as NSError
            let isMissingFile = nsError.domain == NSCocoaErrorDomain
                && nsError.code == NSFileReadNoSuchFileError
            if isMissingFile {
                logger.debug("No session file found — starting fresh.")
            } else {
                logger.error("Session restore failed: \(error.localizedDescription, privacy: .public)")
            }
            let fallback = Tab(assetsBaseURL: tabAssetsBaseURL)
            tabs = [fallback]
            rebuildTabIndex()
        }
    }

    private func loadSessionState() -> Result<SessionState, Error> {
        do {
            let data  = try Data(contentsOf: sessionURL)
            let state = try JSONDecoder().decode(SessionState.self, from: data)
            return .success(state)
        } catch {
            return .failure(error)
        }
    }

    private func hydrateRestoredTabs() {
        tabs.forEach { hydrateVisualState(for: $0) }
    }

    private func scheduleSave() {
        guard isPersistenceEnabled else { return }

        pendingSaveTask?.cancel()
        saveVersion &+= 1
        let version = saveVersion

        pendingSaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Defaults.saveDebounceNs)
            guard !Task.isCancelled else { return }

            let state = SessionState(
                tabIDs: self.tabs.map { $0.id },
                activeTabID: self.activeTabID
            )
            let url     = self.sessionURL
            let encoded = try? JSONEncoder().encode(state)
            let log     = self.logger
            let writer  = self.sessionWriter

            Task.detached(priority: .background) {
                guard let data = encoded else { return }
                await writer.write(data: data, version: version, to: url, logger: log)
            }
        }
    }


    private func rebuildTabIndex() {
        tabIndex = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
    }

    private func indexTab(_ tab: Tab) {
        tabIndex[tab.id] = tab
    }

    private func deindexTab(id: UUID) {
        tabIndex.removeValue(forKey: id)
    }

    private func makeTab(from payload: TabTransferPayload) -> Tab {
        let tab = Tab(payload: payload, assetsBaseURL: tabAssetsBaseURL)
        return tab
    }

    func navigateActiveTab(to url: URL) {
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

    @discardableResult
    func createTab(url: URL? = nil) -> Tab {
        let tab = Tab(url: url, assetsBaseURL: tabAssetsBaseURL)

        tabs.append(tab)
        indexTab(tab)
        hydrateVisualState(for: tab)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switchTo(tab.id)
        }

        if url == nil {
            pendingFocusTask?.cancel()
            pendingFocusTask = Task { [weak self, notificationCenter] in
                try? await Task.sleep(nanoseconds: UInt64(Defaults.tabCreationDelay * 1_000_000_000))
                guard !Task.isCancelled, self != nil else { return }
                notificationCenter.post(name: .focusNewTabSearchBar, object: nil)
            }
        }

        scheduleSave()

        return tab
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let tab = tabs[index]
        let payload = tab.toTransferPayload()
        tab.close()
        pushRecentlyClosed(payload)
        tabGroupManager.handleTabClosed(id)

        tabs.remove(at: index)
        deindexTab(id: id)
        removeTabAssets(for: id)

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
        activeTabID = nil
        syncActiveTabURL()
        scheduleSave()
    }

    func cycleBookmarkBarVisibility() {
        switch bookmarkBarVisibility {
        case .always:    bookmarkBarVisibility = .newTabOnly
        case .newTabOnly: bookmarkBarVisibility = .hidden
        case .hidden:    bookmarkBarVisibility = .always
        }
    }

    @discardableResult
    func reopenLastClosedTab() -> Tab? {
        guard let snapshot = recentlyClosed.popLast() else { return nil }
        let tab = makeTab(from: snapshot.payload)

        tabs.append(tab)
        indexTab(tab)
        hydrateVisualState(for: tab)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switchTo(tab.id)
        }
        scheduleSave()
        return tab
    }

    func moveTab(fromOffsets: IndexSet, toOffset: Int) {
        tabs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        tabGroupManager.handleTabsReordered(tabs.map { $0.id })
        scheduleSave()
    }

    func nextTab()     { cycleTab(by: +1) }
    func previousTab() { cycleTab(by: -1) }

    func switchTo(_ id: UUID) {
        guard activeTabID != id else { return }
        setActiveTab(id)
    }

    func setActiveTab(_ id: UUID?) {
        activeTabID = id
        if let id, let tab = tabIndex[id] {
            tab.markActivated()
            tab.markAccessed()
        }
        syncActiveTabURL()
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

    private func syncActiveTabURL() {
        urlSynchronizer.updateCurrentURL(activeTab?.url)
    }

    private func cycleTab(by delta: Int) {
        guard
            let currentID = activeTabID,
            let index = tabs.firstIndex(where: { $0.id == currentID }),
            tabs.count > 1
        else { return }

        let nextIndex = (index + delta + tabs.count) % tabs.count
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            switchTo(tabs[nextIndex].id)
        }
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

    private func hydrateVisualState(for tab: Tab) {
        tab.loadAssets()

        if let special = specialFavicon(for: tab.url) {
            tab.favicon = special
            return
        }

        guard tab.favicon == nil, let faviconURL = defaultFaviconURL(for: tab.url) else { return }

        Task(priority: .utility) { [weak tab, faviconCache] in
            guard let image = await faviconCache.fetchImage(for: faviconURL) else { return }
            await MainActor.run {
                guard let tab, tab.favicon == nil else { return }
                tab.favicon = image
            }
        }
    }

    private func defaultFaviconURL(for pageURL: URL?) -> URL? {
        guard
            let pageURL,
            let scheme = pageURL.scheme?.lowercased(),
            let host   = pageURL.host,
            scheme == "http" || scheme == "https"
        else { return nil }

        var components    = URLComponents()
        components.scheme = scheme
        components.host   = host
        components.path   = "/favicon.ico"
        return components.url
    }

    private func specialFavicon(for pageURL: URL?) -> NSImage? {
        guard pageURL?.scheme?.lowercased() == "illuminate" else { return nil }
        switch pageURL?.host?.lowercased() {
        case "passwords":
            return NSImage(systemSymbolName: "key.fill", accessibilityDescription: "Passwords")
        case "cookies":
            return NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Cookies")
        case "protection":
            return NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "Protection")
        case "downloads":
            return NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Downloads")
        case "history":
            return NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "History")
        default:
            return nil
        }
    }

    private func removeTabAssets(for id: UUID) {
        let folder = tabAssetsBaseURL
            .appendingPathComponent("TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)

        do {
            try FileManager.default.removeItem(at: folder)
        } catch {
            let nsError = error as NSError
            let isMissingFile = nsError.domain == NSCocoaErrorDomain
                && nsError.code == NSFileNoSuchFileError
            guard !isMissingFile else { return }
            logger.debug(
                "Could not remove tab assets for \(id.uuidString): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func updateThemeFromBackground(applyTheme: Bool) {
        backgroundThemeTask?.cancel()

        guard !backgroundImageURL.isEmpty, let url = URL(string: backgroundImageURL) else {
            backgroundImagePalette = []
            return
        }

        let expectedURLString = backgroundImageURL
        backgroundThemeTask = Task { [weak self] in
            let palette = await ImageColorExtractor.shared.extractPalette(from: url)
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                guard self.backgroundImageURL == expectedURLString else { return }

                withAnimation(.easeInOut(duration: 0.8)) {
                    self.backgroundImagePalette = palette
                    if applyTheme, let first = palette.first {
                        self.windowThemeColor = first
                    }
                }
            }
        }
    }

    private func persistIfEnabled(_ value: some UserDefaultsStorable, forKey key: String) {
        guard isPersistenceEnabled else { return }
        userDefaults.set(value, forKey: scopedKey(key))
    }

    private func scopedKey(_ key: String) -> String {
        Self.scopedKey(key, profileID: activeProfileID)
    }

    private static func scopedKey(_ key: String, profileID: UUID?) -> String {
        guard let profileID else { return key }
        return "profile.\(profileID.uuidString).\(key)"
    }

    private func setupObservers() {
        typealias Handler = @MainActor @Sendable () -> Void

        let pairs: [(Notification.Name, Handler)] = [
            (.newTab,          { [weak self] in self?.createTab() }),
            (.reloadActiveTab, { [weak self] in self?.activeTab?.reload() }),
            (.goBack,          { [weak self] in self?.activeTab?.webView?.goBack() }),
            (.goForward,       { [weak self] in self?.activeTab?.webView?.goForward() }),
            (.reopenTab,       { [weak self] in self?.reopenLastClosedTab() }),
            (.nextTab,         { [weak self] in self?.nextTab() }),
            (.previousTab,     { [weak self] in self?.previousTab() }),
            (.openDevTools,    { [weak self] in self?.activeTab?.openDevTools() }),
            (.zoomIn,          { [weak self] in self?.activeTab?.zoomIn() }),
            (.zoomOut,         { [weak self] in self?.activeTab?.zoomOut() }),
            (.resetZoom,       { [weak self] in self?.activeTab?.resetZoom() }),
            (.toggleFullScreen, { NSApp.keyWindow?.toggleFullScreen(nil) }),
            (.showHistory,     { [weak self] in self?.navigateActiveTab(to: URL(string: "illuminate://history")!) }),
            (Notification.Name.closeActiveTab, { [weak self] in self?.closeActiveTab() }),
            (Notification.Name.closeAllTabs, { [weak self] in self?.clearAllTabs() }),
            (Notification.Name.toggleBookmarkBar, { [weak self] in self?.cycleBookmarkBarVisibility() }),
            (.newTabGroup, { [weak self] in
                guard let self, let activeTabID = self.activeTabID else { return }
                self.tabGroupManager.createGroup(name: "", color: .blue, tabIDs: [activeTabID])
            }),
            (.closeCurrentGroup, { [weak self] in
                guard let self, let activeTabID = self.activeTabID,
                      let group = self.tabGroupManager.group(for: activeTabID) else { return }
                let tabIDs = group.tabIDs
                self.tabGroupManager.closeGroup(group.id, tabs: self.tabs)
                for tabID in tabIDs {
                    self.closeTab(id: tabID)
                }
            }),
            (.moveTabToLeftGroup, { [weak self] in
                guard let self, let activeTabID = self.activeTabID else { return }
                self.moveActiveTabToAdjacentGroup(direction: -1)
            }),
            (.moveTabToRightGroup, { [weak self] in
                guard let self, let activeTabID = self.activeTabID else { return }
                self.moveActiveTabToAdjacentGroup(direction: +1)
            }),
        ]

        var tokens = pairs.map { name, handler in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in handler() }
            }
        }

        let openURLToken = notificationCenter.addObserver(
            forName: .openURL, object: nil, queue: .main
        ) { [weak self] notification in
            guard let url = notification.object as? URL else { return }
            Task { @MainActor [weak self] in
                self?.navigateActiveTab(to: url)
            }
        }
        tokens.append(openURLToken)
        observerTokens = tokens
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
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) as? Bool ?? defaultValue
    }
}

protocol UserDefaultsStorable {}
extension String: UserDefaultsStorable {}
extension Bool:   UserDefaultsStorable {}
extension Int:    UserDefaultsStorable {}
extension Double: UserDefaultsStorable {}