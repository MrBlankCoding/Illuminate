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
                BrowserCommand("Close Tab",          shortcut: "w")                     { .closeActiveTab }
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

            BrowserCommand("Toggle Sidebar", shortcut: "s") { .toggleSidebar }

            Divider()

            BrowserCommand("Find in Page",    shortcut: "f")                          { .findInPage }
            BrowserCommand("Developer Tools", shortcut: "i", modifiers: [.command, .shift]) { .openDevTools }
        }

        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .toolbar) {
            BrowserCommand("Zoom In",     shortcut: "+") { .zoomIn }
            BrowserCommand("Zoom Out",    shortcut: "-") { .zoomOut }
            BrowserCommand("Actual Size", shortcut: "0") { .resetZoom }
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

private extension Notification.Name {
    static let closeActiveTab = Notification.Name("closeActiveTab")
}
