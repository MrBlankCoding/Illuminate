//
//  AppCommands.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct AppCommands: Commands {
    let shortcutHandler: KeyboardShortcutHandler

    var body: some Commands {

        CommandMenu("Browser") {
            Group {
                BrowserCommand("New Tab",            shortcut: "t")                     { .newTab }
                BrowserCommand("Reopen Closed Tab",  shortcut: "t", modifiers: [.command, .shift]) { .reopenTab }
                BrowserCommand("Focus URL Bar",      shortcut: "l")                     { .focusURLBar }
                BrowserCommand("Refresh Page",       shortcut: "r")                     { .reloadActiveTab }
            }

            Divider()

            Group {
                BrowserCommand("Go Back",    shortcut: .leftArrow)  { .goBack }
                BrowserCommand("Go Forward", shortcut: .rightArrow) { .goForward }
            }

            Divider()

            Group {
                BrowserCommand("Next Tab",     shortcut: .downArrow) { .nextTab }
                BrowserCommand("Previous Tab", shortcut: .upArrow)   { .previousTab }
            }

            Divider()

            BrowserCommand("Close All Tabs", shortcut: "w", modifiers: [.command, .shift]) { .closeAllTabs }

            Divider()

            BrowserCommand("Find in Page",    shortcut: "f")                          { .findInPage }
            BrowserCommand("Toggle Full Screen", shortcut: "f", modifiers: [.command, .shift]) { .toggleFullScreen }
        }

        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .saveItem) {
            CloseTabCommand()
        }

        CommandGroup(replacing: .toolbar) {
            BrowserCommand("Zoom In",     shortcut: "+") { .zoomIn }
            BrowserCommand("Zoom Out",    shortcut: "-") { .zoomOut }
            BrowserCommand("Actual Size", shortcut: "0") { .resetZoom }

            Divider()

            BrowserCommand("Developer Tools", shortcut: "i", modifiers: [.command, .shift]) { .openDevTools }

            Divider()

            BookmarkBarMenuContent()
        }

        CommandGroup(replacing: .sidebar) {}
    }
}

private struct BrowserCommand: View {
    private let title: String
    private let notification: () -> Notification.Name
    private let keyEquivalent: KeyEquivalent
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

    var body: some View {
        Button(title) { post() }
            .keyboardShortcut(keyEquivalent, modifiers: modifiers)
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

private struct BookmarkBarMenuContent: View {
    @FocusedValue(\.activeEnvironment) private var environment

    private var currentVisibility: BookmarkBarVisibility {
        environment?.tabManager.bookmarkBarVisibility ?? .always
    }

    var body: some View {
        Section("Bookmark Bar") {
            Button {
                set(.always)
            } label: {
                Label(
                    BookmarkBarVisibility.always.displayName,
                    systemImage: currentVisibility == .always ? "checkmark" : ""
                )
            }

            Button {
                set(.newTabOnly)
            } label: {
                Label(
                    BookmarkBarVisibility.newTabOnly.displayName,
                    systemImage: currentVisibility == .newTabOnly ? "checkmark" : ""
                )
            }

            Button {
                set(.hidden)
            } label: {
                Label(
                    BookmarkBarVisibility.hidden.displayName,
                    systemImage: currentVisibility == .hidden ? "checkmark" : ""
                )
            }
        }

        Divider()

        Button("Toggle Bookmark Bar") {
            NotificationCenter.default.post(name: .toggleBookmarkBar, object: nil)
        }
        .keyboardShortcut("b", modifiers: [.command, .shift])
    }

    private func set(_ visibility: BookmarkBarVisibility) {
        environment?.tabManager.bookmarkBarVisibility = visibility
    }
}

