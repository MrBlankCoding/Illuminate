//
//  AppCommands.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import KeyboardShortcuts
import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {

        CommandMenu("Browser") {
            Group {
                BrowserCommand("New Tab",             name: .newTab)            { .newTab }
                BrowserCommand("Reopen Closed Tab",  name: .reopenClosedTab)   { .reopenTab }
                BrowserCommand("Focus URL Bar",      name: .focusURLBar)       { .focusURLBar }
                BrowserCommand("Copy Current URL",   name: .copyCurrentURL)    { .copyCurrentURL }
                BrowserCommand("Refresh Page",       name: .reloadPage)        { .reloadActiveTab }
            }

            Divider()

            Group {
                BrowserCommand("Go Back",    name: .goBack)    { .goBack }
                BrowserCommand("Go Forward", name: .goForward) { .goForward }
            }

            Divider()

            Group {
                BrowserCommand("Next Tab",                  name: .nextTab)               { .nextTab }
                BrowserCommand("Previous Tab",              name: .previousTab)           { .previousTab }
                BrowserCommand("Switch to Most Recent Tab", name: .switchToMostRecentTab) { .switchToMostRecentTab }
            }

            Divider()

            Group {
                BrowserCommand("New Tab Group",            name: .newTabGroup)         { .newTabGroup }
                BrowserCommand("Close Current Group",      name: .closeCurrentGroup)   { .closeCurrentGroup }
                BrowserCommand("Move Tab to Left Group",   name: .moveTabToLeftGroup)  { .moveTabToLeftGroup }
                BrowserCommand("Move Tab to Right Group",  name: .moveTabToRightGroup) { .moveTabToRightGroup }
            }

            Divider()

            BrowserCommand("Find in Page",        name: .findInPage)       { .findInPage }
            BrowserCommand("Toggle Full Screen", name: .toggleFullScreen) { .toggleFullScreen }

            Divider()

            BrowserCommand("Developer Tools", name: .developerTools) { .openDevTools }
        }

        CommandMenu("History") {
            RecentlyVisitedMenuContent()

            Divider()

            BrowserCommand("Reopen Closed Tab", name: .reopenClosedTab) { .reopenTab }

            Divider()

            BrowserCommand("Clear History\u{2026}", name: .clearHistory) { .clearHistory }

            Divider()

            BrowserCommand("Show All History", name: .showAllHistory) { .showHistory }
        }

        CommandGroup(replacing: .saveItem) {
            CloseTabCommand()
        }

        CommandGroup(replacing: .toolbar) {
            BrowserCommand("Zoom In",     name: .zoomIn)    { .zoomIn }
            BrowserCommand("Zoom Out",    name: .zoomOut)   { .zoomOut }
            BrowserCommand("Actual Size", name: .resetZoom) { .resetZoom }
        }

        CommandGroup(replacing: .printItem) {
            BrowserCommand("Save Page as PDF", name: .savePageAsPDF) { .savePageAsPDF }
            BrowserCommand("Print Page",       name: .printPage)     { .printPage }
        }

        CommandGroup(replacing: .sidebar) {}
    }
}

private struct BrowserCommand: View {
    private let title: String
    private let shortcutName: KeyboardShortcuts.Name?
    private let notification: () -> Notification.Name

    init(
        _ title: String,
        name: KeyboardShortcuts.Name,
        _ notification: @escaping () -> Notification.Name
    ) {
        self.title = title
        self.shortcutName = name
        self.notification = notification
    }

    init(
        _ title: String,
        _ notification: @escaping () -> Notification.Name
    ) {
        self.title = title
        self.shortcutName = nil
        self.notification = notification
    }

    var body: some View {
        Button(title, action: post)
            .modifier(GlobalShortcutModifier(name: shortcutName))
    }

    private func post() {
        NotificationCenter.default.post(name: notification(), object: nil)
    }
}

private struct GlobalShortcutModifier: ViewModifier {
    let name: KeyboardShortcuts.Name?

    func body(content: Content) -> some View {
        if let name {
            content.globalKeyboardShortcut(name)
        } else {
            content
        }
    }
}

private struct CloseTabCommand: View {
    @FocusedValue(\.activeEnvironment) private var environment

    var body: some View {
        Button("Close Tab") {
            environment?.tabManager.closeActiveTab()
        }
        .globalKeyboardShortcut(.closeTab)
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
        Button("Open File\u{2026}", action: presentOpenPanel)
            .globalKeyboardShortcut(.openFile)
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
