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
    private(set) var activeCount = 0

    private init() {}

    func register() { activeCount += 1 }
    func unregister() { activeCount = max(0, activeCount - 1) }
}
