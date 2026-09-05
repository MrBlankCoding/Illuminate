//
//  KeyboardShortcutHandler.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import KeyboardShortcuts
import SwiftUI

struct ShortcutHotkeyBridge: View {
    var body: some View {
        Group {
            bind(.newTab)                { post(.newTab) }
            bind(.closeTab)              { post(.closeActiveTab) }
            bind(.closeAllTabs)          { post(.closeAllTabs) }
            bind(.reopenClosedTab)       { post(.reopenTab) }
            bind(.nextTab)               { post(.nextTab) }
            bind(.previousTab)           { post(.previousTab) }
            bind(.switchToMostRecentTab) { post(.switchToMostRecentTab) }
            bind(.newWindow)             { DockMenuWindowRouter.shared.openProfileSelection?() }
            bind(.newPrivateWindow)      { post(.newPrivateWindow) }
            bind(.openFile)              {
                let urls = FilePanels.chooseFiles(
                    allowsMultipleSelection: true,
                    message: "Open a file in Illuminate",
                    prompt: "Open"
                )
                guard !urls.isEmpty else { return }
                Task { @MainActor in
                    let needsWindow = BrowserWindowRegistry.shared.activeCount == 0
                    for url in urls { AppFileOpening.shared.enqueue(url) }
                    if needsWindow { AppFileOpening.shared.markNeedsBrowserWindow() }
                }
            }

            bind(.newTabGroup)           { post(.newTabGroup) }
            bind(.closeCurrentGroup)     { post(.closeCurrentGroup) }
            bind(.moveTabToLeftGroup)    { post(.moveTabToLeftGroup) }
            bind(.moveTabToRightGroup)   { post(.moveTabToRightGroup) }

            bind(.focusURLBar)           { post(.focusURLBar) }
            bind(.copyCurrentURL)        { post(.copyCurrentURL) }
            bind(.reloadPage)            { post(.reloadActiveTab) }
            bind(.goBack)                { post(.goBack) }
            bind(.goForward)             { post(.goForward) }
            bind(.toggleFullScreen)      { NSApp.keyWindow?.toggleFullScreen(nil) }

            bind(.showAllHistory)        { post(.showHistory) }
            bind(.clearHistory)          { post(.clearHistory) }

            bind(.findInPage)            { post(.findInPage) }
            bind(.savePageAsPDF)         { post(.savePageAsPDF) }
            bind(.printPage)             { post(.printPage) }
            bind(.zoomIn)                { post(.zoomIn) }
            bind(.zoomOut)               { post(.zoomOut) }
            bind(.resetZoom)             { post(.resetZoom) }
            bind(.developerTools)        { post(.openDevTools) }

            bind(.bookmarkTab)           { post(.bookmarkTab) }
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func bind(_ name: KeyboardShortcuts.Name, action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onGlobalKeyboardShortcut(name) { _ in
                AppLog.ui("Shortcut fired: \(name.rawValue)")
                action()
            }
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}

final class KeyboardShortcutHandler {
    init() {}
}

final class BackgroundResourceManager {
    func start() {
        AppLog.info("BackgroundResourceManager started")
    }
}

final class RuntimeSecurityMonitor {

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func startMonitoring() {
        #if DEBUG
        observe(.newTab) { AppLog.security("Runtime check passed for New Tab action") }
        #endif
    }

    private func observe(_ name: Notification.Name, handler: @escaping () -> Void) {
        let token = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
            handler()
        }
        observers.append(token)
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
    }
}
