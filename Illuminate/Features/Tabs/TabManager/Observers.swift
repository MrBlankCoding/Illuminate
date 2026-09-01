//
//  TabManagerObservers.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import Foundation
import SwiftUI
import WebKit

@MainActor
extension TabManager {
    func setupObservers() {
        typealias Handler = @MainActor @Sendable () -> Void

        let pairs: [(Notification.Name, Handler)] = [
            (.newTab,          { [weak self] in self?.createTab() }),
            (.newEasel,        { [weak self] in self?.createEasel() }),
            (.reloadActiveTab, { [weak self] in self?.activeTab?.reload() }),
            (.copyCurrentURL,  { [weak self] in self?.copyCurrentURL() }),
            (.goBack,          { [weak self] in self?.activeTab?.webView?.goBack() }),
            (.goForward,       { [weak self] in self?.activeTab?.webView?.goForward() }),
            (.reopenTab,       { [weak self] in self?.reopenLastClosedTab() }),
            (.nextTab,         { [weak self] in self?.nextTab() }),
            (.previousTab,     { [weak self] in self?.previousTab() }),
            (.switchToMostRecentTab, { [weak self] in self?.switchToMostRecentTab() }),
            (.openDevTools,    { [weak self] in self?.activeTab?.openDevTools() }),
            (.zoomIn,          { [weak self] in self?.activeTab?.zoomIn() }),
            (.zoomOut,         { [weak self] in self?.activeTab?.zoomOut() }),
            (.resetZoom,       { [weak self] in self?.activeTab?.resetZoom() }),
            (.printPage,        { [weak self] in self?.activeTab?.printPage() }),
            (.savePageAsPDF,    { [weak self] in self?.saveActiveTabAsPDF() }),
            (.toggleFullScreen, { NSApp.keyWindow?.toggleFullScreen(nil) }),
            (.showHistory,     { [weak self] in self?.navigateActiveTab(to: IlluminatePage.history.url) }),
            (Notification.Name.closeActiveTab, { [weak self] in self?.closeActiveTab() }),
            (Notification.Name.closeAllTabs, { [weak self] in self?.clearAllTabs() }),

            (.newTabGroup, { [weak self] in
                guard let self, let activeTabID = self.activeTabID else { return }
                self.tabGroupManager.createGroup(name: "", color: .blue, tabIDs: [activeTabID])
            }),
            (.closeCurrentGroup, { [weak self] in
                guard let self else { return }
                guard let activeTabID = self.activeTabID,
                      let group = self.tabGroupManager.group(for: activeTabID) else { return }
                let tabIDs = group.tabIDs
                self.tabGroupManager.closeGroup(group.id, tabs: self.tabs)
                for tabID in tabIDs {
                    self.closeTab(id: tabID)
                }
            }),
            (.moveTabToLeftGroup, { [weak self] in
                guard let self else { return }
                guard self.activeTabID != nil else { return }
                self.moveActiveTabToAdjacentGroup(direction: -1)
            }),
            (.moveTabToRightGroup, { [weak self] in
                guard let self else { return }
                guard self.activeTabID != nil else { return }
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

        let pendingFilesToken = notificationCenter.addObserver(
            forName: .pendingFilesChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppFileOpening.shared.drain(into: self)
            }
        }
        tokens.append(pendingFilesToken)

        func observeExtensions() {
            withObservationTracking {
                _ = extensionManager.installedExtensions
            } onChange: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, !self.extensionObserverCancelled else { return }
                    self.handleExtensionListChanged()
                    observeExtensions()
                }
            }
        }
        observeExtensions()

        observerTokens = tokens
    }

    func handleExtensionListChanged() {
        let currentIDs = extensionManager.installedExtensions.map(\.uniqueIdentifier)
        guard currentIDs != lastReloadedExtensionIDs else { return }
        lastReloadedExtensionIDs = currentIDs

        AppLog.debug("[TabManager] Extension list changed - installed extensions count: \(extensionManager.installedExtensions.count)")
        for tab in tabs {
            if tab.url != nil {
                tab.reload()
            }
        }
    }

    func copyCurrentURL() {
        guard let url = activeTab?.url else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
    }
}
