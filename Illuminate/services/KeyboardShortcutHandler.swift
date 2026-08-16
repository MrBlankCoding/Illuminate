//
//  KeyboardShortcutHandler.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import Foundation

final class KeyboardShortcutHandler {
    private struct Shortcut {
        enum Trigger {
            case character(String)
            case keyCode(UInt16)
        }
        let modifiers: NSEvent.ModifierFlags
        let trigger: Trigger
        let action: Notification.Name
    }

    private enum KeyCode {
        static let leftArrow:  UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow:  UInt16 = 125
        static let upArrow:    UInt16 = 126
    }

    private let shortcuts: [Shortcut]

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.shortcuts = Self.makeShortcuts()
        self.notificationCenter = notificationCenter
    }

    private static func makeShortcuts() -> [Shortcut] {
        [
            Shortcut(modifiers: .command, trigger: .character("t"), action: .newTab),
            Shortcut(modifiers: .command, trigger: .character("w"), action: .closeActiveTab),
            Shortcut(modifiers: .command, trigger: .character("l"), action: .focusURLBar),
            Shortcut(modifiers: .command, trigger: .character("r"), action: .reloadActiveTab),
            Shortcut(modifiers: .command, trigger: .character("b"), action: .bookmarkTab),
            Shortcut(modifiers: .command, trigger: .character("f"), action: .findInPage),
            Shortcut(modifiers: .command, trigger: .character("+"), action: .zoomIn),
            Shortcut(modifiers: .command, trigger: .character("="), action: .zoomIn),
            Shortcut(modifiers: .command, trigger: .character("-"), action: .zoomOut),
            Shortcut(modifiers: .command, trigger: .character("0"), action: .resetZoom),
            Shortcut(modifiers: .command, trigger: .keyCode(KeyCode.leftArrow), action: .goBack),
            Shortcut(modifiers: .command, trigger: .keyCode(KeyCode.rightArrow), action: .goForward),
            Shortcut(modifiers: .command, trigger: .keyCode(KeyCode.downArrow), action: .nextTab),
            Shortcut(modifiers: .command, trigger: .keyCode(KeyCode.upArrow), action: .previousTab),
            Shortcut(modifiers: [.command, .shift], trigger: .character("i"), action: .openDevTools),
            Shortcut(modifiers: [.command, .shift], trigger: .character("t"), action: .reopenTab),
            Shortcut(modifiers: [.command, .shift], trigger: .character("w"), action: .closeAllTabs),
            Shortcut(modifiers: [.command, .shift], trigger: .character("f"), action: .toggleFullScreen),
        ]
    }

    func bookmarkTab() {
        post(.bookmarkTab)
    }

    func openNewTab() { post(.newTab) }
    func closeActiveTab() { post(.closeActiveTab) }
    func closeAllTabs() { post(.closeAllTabs) }
    func reopenTab() { post(.reopenTab) }
    func focusURLBar() { post(.focusURLBar) }
    func reloadActiveTab() { post(.reloadActiveTab) }
    func goBack() { post(.goBack) }
    func goForward() { post(.goForward) }
    func nextTab() { post(.nextTab) }
    func previousTab() { post(.previousTab) }
    func findInPage() { post(.findInPage) }
    func openDevTools() { post(.openDevTools) }
    func toggleFullScreen() { post(.toggleFullScreen) }
    func zoomIn() { post(.zoomIn) }
    func zoomOut() { post(.zoomOut) }
    func resetZoom() { post(.resetZoom) }

    nonisolated func lookupShortcutBy(character: String, modifiers: NSEvent.ModifierFlags) -> Notification.Name? {
        let key = character.lowercased()
        for shortcut in shortcuts where shortcut.modifiers == modifiers {
            if case .character(let match) = shortcut.trigger, match.lowercased() == key {
                return shortcut.action
            }
        }
        return nil
    }

    nonisolated func lookupShortcutBy(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Notification.Name? {
        for shortcut in shortcuts where shortcut.modifiers == modifiers {
            if case .keyCode(let match) = shortcut.trigger, match == keyCode {
                return shortcut.action
            }
        }
        return nil
    }

    private func post(_ name: Notification.Name) {
        AppLog.ui("Shortcut fired: \(name.rawValue)")
        notificationCenter.post(name: name, object: nil)
    }
}


// TODO: create an actual manager
final class BackgroundResourceManager {
    func start() {
        AppLog.info("BackgroundResourceManager started")
    }
}

// TODO: replace logging stub with real integrity/policy checks.
final class RuntimeSecurityMonitor {

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func startMonitoring() {
        // This observer exists as a placeholder for future integrity/policy checks.
        // In release builds, emitting a security log on every new-tab creation
        // adds a NotificationCenter observer + os_log call with no security value.
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
