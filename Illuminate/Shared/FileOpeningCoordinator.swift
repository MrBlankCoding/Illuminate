//
//  FileOpeningCoordinator.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import Combine
import Foundation
import SwiftUI


@MainActor
final class AppFileOpening: ObservableObject {
    static let shared = AppFileOpening()

    @Published private(set) var pendingURLs: [URL] = []
    @Published var needsBrowserWindow = false

    private var accessedURLs = Set<URL>()

    private init() {}

    func enqueue(_ url: URL) {
        guard url.isFileURL else { return }
        let stable = url.standardizedFileURL
        if accessedURLs.insert(stable).inserted {
            _ = stable.startAccessingSecurityScopedResource()
        }
        if pendingURLs.contains(stable) { return }
        pendingURLs.append(stable)

        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        NotificationCenter.default.post(name: .pendingFilesChanged, object: nil)
    }

    func drain(into tabManager: TabManager) {
        guard !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs.removeAll()
        for url in urls {
            if let viewerURL = IlluminatePage.pdfViewerURL(for: url) {
                tabManager.createTab(url: viewerURL)
            } else {
                tabManager.createTab(url: url)
            }
        }
    }

    func markNeedsBrowserWindow() { needsBrowserWindow = true }
    func clearNeedsBrowserWindow() { needsBrowserWindow = false }
}

@MainActor
final class BrowserWindowRegistry: ObservableObject {
    static let shared = BrowserWindowRegistry()

    private var windows: [ObjectIdentifier: WeakWindow] = [:]
    private var pendingOpens: [UUID: Date] = [:]
    private static let pendingOpenLifetime: TimeInterval = 5

    var activeCount: Int {
        prune()
        return windows.values.filter { $0.window?.isVisible == true }.count
    }

    private init() {}

    func register(_ window: NSWindow, route: BrowserWindowRoute?) {
        prune()
        windows[ObjectIdentifier(window)] = WeakWindow(window, route: route)
        if case let .profile(profileID) = route {
            pendingOpens[profileID] = nil
        }
    }

    func unregister(_ window: NSWindow) {
        windows.removeValue(forKey: ObjectIdentifier(window))
        prune()
    }

    func hasOpenWindow(for profileID: UUID) -> Bool {
        prune()
        return containsOpenWindow(for: profileID)
    }

    private func containsOpenWindow(for profileID: UUID) -> Bool {
        windows.values.contains { entry in
            guard let window = entry.window, window.isVisible else { return false }
            if case let .profile(id)? = entry.route { return id == profileID }
            return false
        }
    }

    func beginOpening(for profileID: UUID) -> Bool {
        prune()
        guard !containsOpenWindow(for: profileID), pendingOpens[profileID] == nil else { return false }
        pendingOpens[profileID] = Date()
        return true
    }

    func cancelOpening(for profileID: UUID) {
        pendingOpens[profileID] = nil
    }

    private func prune() {
        windows = windows.filter { _, value in
            guard let window = value.window else { return false }
            return window.isVisible
        }

        let now = Date()
        pendingOpens = pendingOpens.filter { profileID, date in
            if containsOpenWindow(for: profileID) { return false }
            return now.timeIntervalSince(date) < Self.pendingOpenLifetime
        }
    }

    private struct WeakWindow {
        weak var window: NSWindow?
        let route: BrowserWindowRoute?

        init(_ window: NSWindow, route: BrowserWindowRoute?) {
            self.window = window
            self.route = route
        }
    }
}
