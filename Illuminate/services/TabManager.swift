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
    @Published private(set) var tabGroups: [TabGroup] = []
    @Published var isResizing: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var backgroundImagePalette: [Color] = []

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

    var canReopenTab: Bool { !recentlyClosed.isEmpty }

    private let notificationCenter: NotificationCenter
    private let urlSynchronizer: URLSynchronizer
    private let userDefaults: UserDefaults
    private let isPersistenceEnabled: Bool
    private let sessionURL: URL
    private let faviconCache: FaviconCache
    private let logger = Logger(subsystem: "com.illuminate", category: "TabManager")

    private var activeProfileID: UUID?

    // O(1) tab access by ID; kept in sync with the `tabs` array.
    private var tabIndex: [UUID: Tab] = [:]

    private var recentlyClosed: [ClosedTabSnapshot] = []
    private var isInitializing = true
    private var pendingSaveTask: Task<Void, Never>?
    private var backgroundThemeTask: Task<Void, Never>?
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
            tabGroups   = state.tabGroups
            activeTabID = state.activeTabID
            if let ids = state.tabIDs {
                tabs = ids.map { Tab(id: $0, assetsBaseURL: tabAssetsBaseURL) }
            }
            rebuildTabIndex()
        case .failure(let error):
            logger.error("Session restore failed: \(error.localizedDescription, privacy: .public)")
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
        pendingSaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Defaults.saveDebounceNs)
            guard !Task.isCancelled else { return }

            let state = SessionState(
                tabIDs: self.tabs.map { $0.id },
                tabGroups: self.tabGroups,
                activeTabID: self.activeTabID
            )
            let url     = self.sessionURL
            let encoded = try? JSONEncoder().encode(state)
            let log     = self.logger

            Task.detached(priority: .background) {
                guard let data = encoded else { return }
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    log.error("[TabManager] Session write failed: \(error.localizedDescription, privacy: .public)")
                }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + Defaults.tabCreationDelay) { [notificationCenter] in
                notificationCenter.post(name: .focusNewTabSearchBar, object: nil)
            }
        }
        
        scheduleSave()

        return tab
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let tab = tabs[index]
        tab.close()
        pushRecentlyClosed(tab.toTransferPayload())

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
            $0.close()
            pushRecentlyClosed($0.toTransferPayload())
            removeTabAssets(for: $0.id)
        }
        tabs.removeAll()
        tabIndex.removeAll()
        activeTabID = nil
        syncActiveTabURL()
        scheduleSave()
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

    func openSettingsTab() {
        let settingsURLString = "illuminate://settings"

        if let existing = tabs.first(where: { $0.url?.absoluteString == settingsURLString }) {
            switchTo(existing.id)
            return
        }

        guard let settingsURL = URL(string: settingsURLString) else {
            logger.error("Invalid settings URL string: \(settingsURLString, privacy: .public)")
            return
        }

        let tab = createTab(url: settingsURL)
        tab.title = "Settings"
    }

    func createTabGroup(name: String, color: String) {
        tabGroups.append(TabGroup(name: name, color: color))
        scheduleSave()
    }

    func removeTabGroup(id: UUID) {
        tabGroups.removeAll { $0.id == id }
        tabs.filter { $0.groupID == id }.forEach { $0.groupID = nil }
        scheduleSave()
    }

    func toggleGroupExpansion(id: UUID) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        tabGroups[index].isExpanded.toggle()
        scheduleSave()
    }

    func setTabGroup(tabID: UUID, groupID: UUID?) {
        tabIndex[tabID]?.groupID = groupID
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
        guard
            pageURL?.scheme?.lowercased() == "illuminate",
            pageURL?.host?.lowercased()   == "settings"
        else { return nil }
        // settings 
        return NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings")
    }

    private func removeTabAssets(for id: UUID) {
        let folder = tabAssetsBaseURL
            .appendingPathComponent("TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)

        do {
            try FileManager.default.removeItem(at: folder)
        } catch {
            guard (error as NSError).code != NSFileNoSuchFileError else { return }
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
            (.toggleSidebar,   { [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self?.showSidebar.toggle()
                }
            }),
            (.openDevTools,    { [weak self] in self?.activeTab?.openDevTools() }),
            (.zoomIn,          { [weak self] in self?.activeTab?.zoomIn() }),
            (.zoomOut,         { [weak self] in self?.activeTab?.zoomOut() }),
            (.resetZoom,       { [weak self] in self?.activeTab?.resetZoom() }),
            (.toggleFullScreen, { NSApp.keyWindow?.toggleFullScreen(nil) }),
            (Notification.Name.closeActiveTab, { [weak self] in self?.closeActiveTab() }),
            (Notification.Name.closeAllTabs, { [weak self] in self?.clearAllTabs() }),
        ]

        observerTokens = pairs.map { name, handler in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in handler() }
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
