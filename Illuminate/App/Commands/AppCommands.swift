//
//  AppCommands.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import Observation

@Observable
final class MenuRefreshTrigger {
    var value = 0
}

struct AppCommands: Commands {
    let shortcutHandler: KeyboardShortcutHandler
    var menuRefreshTrigger: MenuRefreshTrigger

    var body: some Commands {

        CommandMenu("Browser") {
            Group {
                BrowserCommand("New Tab",            shortcut: "t")                     { .newTab }
                BrowserCommand("New Easel",          shortcut: "e", modifiers: [.command, .shift]) { .newEasel }
                BrowserCommand("Reopen Closed Tab") { .reopenTab }
                BrowserCommand("Focus URL Bar",      shortcut: "l")                     { .focusURLBar }
                BrowserCommand("Copy Current URL",    shortcut: "c", modifiers: [.command, .shift]) { .copyCurrentURL }
                BrowserCommand("Refresh Page",       shortcut: "r")                     { .reloadActiveTab }
            }

            Divider()

            Group {
                BrowserCommand("Go Back",    shortcut: .leftArrow)  { .goBack }
                BrowserCommand("Go Forward", shortcut: .rightArrow) { .goForward }
            }

            Divider()

            Group {
                BrowserCommand("Next Tab",                shortcut: .downArrow) { .nextTab }
                BrowserCommand("Previous Tab",            shortcut: .upArrow)   { .previousTab }
                BrowserCommand("Switch to Most Recent Tab", shortcut: .tab, modifiers: .control) { .switchToMostRecentTab }
            }

            Divider()

            Group {
                BrowserCommand("New Tab Group", shortcut: "g", modifiers: [.command, .option]) { .newTabGroup }
                BrowserCommand("Close Current Group", shortcut: "w", modifiers: [.command, .option, .shift]) { .closeCurrentGroup }
                BrowserCommand("Move Tab to Left Group", shortcut: .leftArrow, modifiers: [.command, .option]) { .moveTabToLeftGroup }
                BrowserCommand("Move Tab to Right Group", shortcut: .rightArrow, modifiers: [.command, .option]) { .moveTabToRightGroup }
            }

            Divider()

            BrowserCommand("Find in Page",    shortcut: "f")                          { .findInPage }
            BrowserCommand("Toggle Full Screen", shortcut: "f", modifiers: [.command, .shift]) { .toggleFullScreen }

            Divider()

            BrowserCommand("Developer Tools", shortcut: "i", modifiers: [.command, .option]) { .openDevTools }
        }

        CommandMenu("History") {
            RecentlyVisitedMenuContent()

            Divider()

            BrowserCommand("Reopen Closed Tab", shortcut: "t", modifiers: [.command, .shift]) { .reopenTab }

            Divider()

            BrowserCommand("Clear History…", shortcut: "\u{08}", modifiers: [.command, .shift]) { .clearHistory }

            Divider()

            BrowserCommand("Show All History", shortcut: "y") { .showHistory }
        }

        CommandGroup(replacing: .saveItem) {
            CloseTabCommand()
        }

        CommandGroup(replacing: .toolbar) {
            BrowserCommand("Zoom In",     shortcut: "+") { .zoomIn }
            BrowserCommand("Zoom Out",    shortcut: "-") { .zoomOut }
            BrowserCommand("Actual Size", shortcut: "0") { .resetZoom }
        }

        CommandGroup(replacing: .printItem) {
            BrowserCommand("Save Page as PDF", shortcut: "s", modifiers: [.command, .shift]) { .savePageAsPDF }
            BrowserCommand("Print Page", shortcut: "p") { .printPage }
        }

        CommandGroup(replacing: .sidebar) {}
    }
}

private struct BrowserCommand: View {
    private let title: String
    private let notification: () -> Notification.Name
    private let keyEquivalent: KeyEquivalent?
    private let modifiers: EventModifiers

    init(
        _ title: String,
        shortcut: String,
        modifiers: EventModifiers = .command,
        _ notification: @escaping () -> Notification.Name
    ) {
        self.title = title
        self.keyEquivalent = KeyEquivalent(shortcut.first ?? " ")
        self.modifiers = modifiers
        self.notification = notification
    }

    init(
        _ title: String,
        shortcut: KeyEquivalent,
        modifiers: EventModifiers = .command,
        _ notification: @escaping () -> Notification.Name
    ) {
        self.title = title
        self.keyEquivalent = shortcut
        self.modifiers = modifiers
        self.notification = notification
    }

    init(
        _ title: String,
        _ notification: @escaping () -> Notification.Name
    ) {
        self.title = title
        self.keyEquivalent = nil
        self.modifiers = []
        self.notification = notification
    }

    var body: some View {
        if let keyEquivalent {
            Button(title) { post() }
                .keyboardShortcut(keyEquivalent, modifiers: modifiers)
        } else {
            Button(title) { post() }
        }
    }

    private func post() {
        NotificationCenter.default.post(name: notification(), object: nil)
    }
}

private struct CloseTabCommand: View {
    @FocusedValue(\.activeEnvironment) private var environment

    var body: some View {
        Button("Close Tab") {
            environment?.tabManager.closeActiveTab()
        }
        .keyboardShortcut("w", modifiers: .command)
        .disabled(environment?.tabManager.activeTabID == nil)
    }
}


private struct RecentlyVisitedMenuContent: View {
    @FocusedValue(\.activeEnvironment) private var environment

    private var recentEntries: [HistoryEntry] {
        environment?.historyManager.recentEntries.prefix(10).map { $0 } ?? []
    }

    var body: some View {
        if recentEntries.isEmpty {
            Button("No Recent History") {}
                .disabled(true)
        } else {
            ForEach(recentEntries) { entry in
                Button(entry.displayTitle) {
                    guard let url = entry.url else { return }
                    NotificationCenter.default.post(
                        name: .openURL,
                        object: url
                    )
                }
            }
        }
    }
}

struct OpenFileCommand: View {
    @FocusedValue(\.activeEnvironment) private var environment

    var body: some View {
        Button("Open File…") { presentOpenPanel() }
            .keyboardShortcut("o", modifiers: .command)
    }

    private func presentOpenPanel() {
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
}
