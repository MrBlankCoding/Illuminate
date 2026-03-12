//
//  TabManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Combine
import Foundation
import SwiftUI
import WebKit

struct ClosedTabSnapshot {
    let payload: TabTransferPayload
}

@MainActor
final class TabManager: ObservableObject {

    private enum Defaults {
        static let themeColor = "89BBFF"
        static let maxRecentlyClosed = 25
        static let saveDebounce: UInt64 = 500_000_000
    }

    private enum SuspensionPolicy {
        static let highTabCount = 25
        static let medTabCount = 10
        static let liveLimitHigh = 5
        static let liveLimitMed = 8
    }

    static let shared = TabManager()
    static let sharedPlaceholder = TabManager(isPersistenceEnabled: false)

    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var activeTabID: UUID?
    @Published private(set) var tabGroups: [TabGroup] = []
    @Published var hoveredSidebarTabID: UUID?
    @Published var isResizing: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var backgroundImagePalette: [Color] = []

    @Published var windowThemeColor: Color {
        didSet {
            guard isPersistenceEnabled else { return }
            userDefaults.set(windowThemeColor.toHex(), forKey: "windowThemeColor")
        }
    }

    @Published var backgroundImageURL: String {
        didSet {
            guard isPersistenceEnabled, !isInitializing else { return }
            userDefaults.set(backgroundImageURL, forKey: "backgroundImageURL")
            updateThemeFromBackground(setTheme: true)
        }
    }

    @Published var showSidebar: Bool {
        didSet {
            guard isPersistenceEnabled else { return }
            userDefaults.set(showSidebar, forKey: "showSidebar")
        }
    }

    @Published var showBackgroundBehindSidebar: Bool {
        didSet {
            guard isPersistenceEnabled else { return }
            userDefaults.set(showBackgroundBehindSidebar, forKey: "showBackgroundBehindSidebar")
        }
    }

    @Published var userInterfaceStyle: UIStyle {
        didSet {
            guard isPersistenceEnabled else { return }
            userDefaults.set(userInterfaceStyle.rawValue, forKey: "userInterfaceStyle")
        }
    }

    var activeTab: Tab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    var canReopenTab: Bool { !recentlyClosed.isEmpty }

    private let notificationCenter: NotificationCenter
    private let hibernationManager: TabHibernationManager
    private let urlSynchronizer: URLSynchronizer
    private let userDefaults: UserDefaults
    private let isPersistenceEnabled: Bool
    private let cachedSessionURL: URL

    private var recentlyClosed: [ClosedTabSnapshot] = []
    private var isInitializing = true
    private var pendingSaveTask: Task<Void, Never>?

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
        notificationCenter: NotificationCenter = .default,
        hibernationManager: TabHibernationManager? = nil,
        urlSynchronizer: URLSynchronizer? = nil,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true
    ) {
        self.notificationCenter = notificationCenter
        self.hibernationManager = hibernationManager ?? TabHibernationManager()
        self.urlSynchronizer = urlSynchronizer ?? URLSynchronizer.shared
        self.userDefaults = userDefaults
        self.isPersistenceEnabled = isPersistenceEnabled
        self.cachedSessionURL = Self.makeSessionURL()

        // Resolve persisted or default values
        let savedHex = isPersistenceEnabled
            ? (userDefaults.string(forKey: "windowThemeColor") ?? Defaults.themeColor)
            : Defaults.themeColor
        self.windowThemeColor = Color(hex: savedHex)
        self.backgroundImageURL = isPersistenceEnabled
            ? (userDefaults.string(forKey: "backgroundImageURL") ?? "") : ""
        self.showSidebar = isPersistenceEnabled
            ? (userDefaults.bool(forKey: "showSidebar", default: true)) : true
        self.showBackgroundBehindSidebar = isPersistenceEnabled
            ? (userDefaults.bool(forKey: "showBackgroundBehindSidebar", default: true)) : true
        let savedStyle = isPersistenceEnabled
            ? (userDefaults.string(forKey: "userInterfaceStyle") ?? "dark") : "dark"
        self.userInterfaceStyle = UIStyle(rawValue: savedStyle) ?? .dark

        if isPersistenceEnabled {
            restoreSession()
        }

        setupObservers()

        if tabs.isEmpty {
            createTab()
        }

        Task { @MainActor [weak self] in
            self?.isInitializing = false
            self?.updateThemeFromBackground(setTheme: false)
        }
    }

    private static func makeSessionURL() -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Illuminate", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("session.json")
    }

    private func restoreSession() {
        if let data = try? Data(contentsOf: cachedSessionURL),
           let state = try? JSONDecoder().decode(SessionState.self, from: data) {
            tabGroups = state.tabGroups
            activeTabID = state.activeTabID
            tabs = state.tabs.map { makeTab(from: $0) }
        } else {
            tabs = [Tab()]
        }
    }

    private func makeTab(from payload: TabTransferPayload) -> Tab {
        let tab = Tab(payload: payload)
        tab.onMetadataUpdate = { [weak self] in self?.saveState() }
        return tab
    }

    private func saveState() {
        guard isPersistenceEnabled else { return }

        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Defaults.saveDebounce)
            guard !Task.isCancelled else { return }

            let state = SessionState(
                tabs: self.tabs.map { $0.toTransferPayload() },
                tabGroups: self.tabGroups,
                activeTabID: self.activeTabID
            )
            let url = self.cachedSessionURL

            Task.detached(priority: .background) {
                if let data = try? JSONEncoder().encode(state) {
                    try? data.write(to: url, options: .atomic)
                }
            }
        }
    }

    @discardableResult
    func createTab(url: URL? = nil) -> Tab {
        let tab = Tab(url: url)
        tab.onMetadataUpdate = { [weak self] in self?.saveState() }
        tabs.append(tab)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switchTo(tab.id)
        }
        applyHibernationPolicy()

        if url == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .focusNewTabSearchBar, object: nil)
            }
        }

        return tab
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let tab = tabs[index]
        pushRecentlyClosed(tab.toTransferPayload())
        tabs.remove(at: index)
        removeTabAssets(for: id)

        if activeTabID == id {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let nextID = tabs.isEmpty ? nil : (tabs[safe: index] ?? tabs.last)?.id
                if let nextID {
                    switchTo(nextID)
                } else {
                    activeTabID = nil
                    syncActiveTabURL()
                }
            }
        }

        saveState()
    }

    func closeActiveTab() {
        guard let activeTabID else { return }
        closeTab(id: activeTabID)
    }

    func clearAllTabs() {
        tabs.forEach { pushRecentlyClosed($0.toTransferPayload()) }
        tabs.removeAll()
        activeTabID = nil
        syncActiveTabURL()
        saveState()
    }

    @discardableResult
    func reopenLastClosedTab() -> Tab? {
        guard let snapshot = recentlyClosed.popLast() else { return nil }
        let tab = makeTab(from: snapshot.payload)
        tabs.append(tab)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switchTo(tab.id)
        }
        saveState()
        return tab
    }

    func moveTab(fromOffsets: IndexSet, toOffset: Int) {
        tabs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveState()
    }

    func nextTab() {
        cycleTab(by: +1)
    }

    func previousTab() {
        cycleTab(by: -1)
    }

    private func cycleTab(by delta: Int) {
        guard let currentID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == currentID }),
              tabs.count > 1 else { return }

        let nextIndex = (index + delta + tabs.count) % tabs.count
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            switchTo(tabs[nextIndex].id)
        }
    }

    func switchTo(_ id: UUID) {
        guard activeTabID != id else { return }
        setActiveTab(id)
        applySuspensionPolicy()
    }

    func setActiveTab(_ id: UUID?) {
        activeTabID = id
        if let tab = tabs.first(where: { $0.id == id }) {
            tab.markActivated()
            tab.markAccessed()
            tab.thaw()
        }
        syncActiveTabURL()
        applyHibernationPolicy()
        applySuspensionPolicy()
        saveState()
    }

    func updateTabURL(tabID: UUID, url: URL?) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        tab.url = url
        if tabID == activeTabID { syncActiveTabURL() }
        saveState()
    }

    func createTabGroup(name: String, color: String) {
        tabGroups.append(TabGroup(name: name, color: color))
        saveState()
    }

    func removeTabGroup(id: UUID) {
        tabGroups.removeAll { $0.id == id }
        tabs.filter { $0.groupID == id }.forEach { $0.groupID = nil }
        saveState()
    }

    func toggleGroupExpansion(id: UUID) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        tabGroups[index].isExpanded.toggle()
        saveState()
    }

    func setTabGroup(tabID: UUID, groupID: UUID?) {
        tabs.first { $0.id == tabID }?.groupID = groupID
        saveState()
    }

    private func syncActiveTabURL() {
        urlSynchronizer.updateCurrentURL(activeTab?.url)
    }

    private func applyHibernationPolicy() {
        guard tabs.count > 50 else { return }
        hibernationManager.hibernateInactiveTabs(tabs: tabs, activeTabID: activeTabID)
    }

    private func applySuspensionPolicy() {
        let count = tabs.count
        guard count > SuspensionPolicy.medTabCount else { return }

        let limit = count > SuspensionPolicy.highTabCount
            ? SuspensionPolicy.liveLimitHigh
            : SuspensionPolicy.liveLimitMed

        let liveTabs = tabs.filter { $0.webView != nil && $0.id != activeTabID }
        guard liveTabs.count > limit else { return }

        let toSuspend = liveTabs.count - limit
        liveTabs
            .sorted { $0.lastAccessed < $1.lastAccessed }
            .prefix(toSuspend)
            .forEach { count > SuspensionPolicy.highTabCount ? $0.suspend() : $0.freeze() }
    }

    private func pushRecentlyClosed(_ payload: TabTransferPayload) {
        recentlyClosed.append(ClosedTabSnapshot(payload: payload))
        if recentlyClosed.count > Defaults.maxRecentlyClosed {
            recentlyClosed.removeFirst()
        }
    }

    private func removeTabAssets(for id: UUID) {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let folder = paths[0]
            .appendingPathComponent("Illuminate/TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
    }

    private func updateThemeFromBackground(setTheme: Bool) {
        guard !backgroundImageURL.isEmpty, let url = URL(string: backgroundImageURL) else {
            backgroundImagePalette = []
            return
        }
        Task {
            let palette = await ImageColorExtractor.shared.extractPalette(from: url)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.8)) {
                    backgroundImagePalette = palette
                    if setTheme, let first = palette.first {
                        windowThemeColor = first
                    }
                }
            }
        }
    }

    private func setupObservers() {
        let pairs: [(Notification.Name, () -> Void)] = [
            (.newTab,             { [weak self] in self?.createTab() }),
            (.reloadActiveTab,    { [weak self] in self?.activeTab?.reload() }),
            (.goBack,             { [weak self] in self?.activeTab?.webView?.goBack() }),
            (.goForward,          { [weak self] in self?.activeTab?.webView?.goForward() }),
            (.reopenTab,          { [weak self] in self?.reopenLastClosedTab() }),
            (.nextTab,            { [weak self] in self?.nextTab() }),
            (.previousTab,        { [weak self] in self?.previousTab() }),
            (.toggleSidebar,      { [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self?.showSidebar.toggle()
                }
            }),
            (.openDevTools,       { [weak self] in self?.activeTab?.openDevTools() }),
            (.zoomIn,             { [weak self] in self?.activeTab?.zoomIn() }),
            (.zoomOut,            { [weak self] in self?.activeTab?.zoomOut() }),
            (.resetZoom,          { [weak self] in self?.activeTab?.resetZoom() }),
            (NSNotification.Name("closeActiveTab"), { [weak self] in self?.closeActiveTab() }),
        ]

        for (name, handler) in pairs {
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in handler() }
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
