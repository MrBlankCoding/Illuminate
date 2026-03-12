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

    /// Arrow key codes
    private enum KeyCode {
        static let leftArrow:  UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow:  UInt16 = 125
        static let upArrow:    UInt16 = 126
    }

    private let shortcuts: [Shortcut] = [
        // ⌘ + character
        .init(modifiers: .command, trigger: .character("t"),      action: .newTab),
        .init(modifiers: .command, trigger: .character("w"),      action: .closeActiveTab),
        .init(modifiers: .command, trigger: .character("l"),      action: .focusURLBar),
        .init(modifiers: .command, trigger: .character("r"),      action: .reloadActiveTab),
        .init(modifiers: .command, trigger: .character("s"),      action: .toggleSidebar),
        .init(modifiers: .command, trigger: .character("b"),      action: .bookmarkTab),
        .init(modifiers: .command, trigger: .character("f"),      action: .findInPage),
        .init(modifiers: .command, trigger: .character("+"),      action: .zoomIn),
        .init(modifiers: .command, trigger: .character("="),      action: .zoomIn),
        .init(modifiers: .command, trigger: .character("-"),      action: .zoomOut),
        .init(modifiers: .command, trigger: .character("0"),      action: .resetZoom),
        // ⌘ + arrow keys
        .init(modifiers: .command, trigger: .keyCode(KeyCode.leftArrow),  action: .goBack),
        .init(modifiers: .command, trigger: .keyCode(KeyCode.rightArrow), action: .goForward),
        .init(modifiers: .command, trigger: .keyCode(KeyCode.downArrow),  action: .nextTab),
        .init(modifiers: .command, trigger: .keyCode(KeyCode.upArrow),    action: .previousTab),
        // ⌘⇧ + character
        .init(modifiers: [.command, .shift], trigger: .character("i"), action: .openDevTools),
        .init(modifiers: [.command, .shift], trigger: .character("t"), action: .reopenTab),
    ]

    private let notificationCenter: NotificationCenter
    private var eventMonitor: Any?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        // Manual monitoring disabled to prevent double-triggering with SwiftUI Commands
        // startMonitoring()
    }

    func bookmarkTab() {
        post(.bookmarkTab)
    }

    func openNewTab() { post(.newTab) }
    func closeActiveTab() { post(.closeActiveTab) }
    func reopenTab() { post(.reopenTab) }
    func focusURLBar() { post(.focusURLBar) }
    func reloadActiveTab() { post(.reloadActiveTab) }
    func goBack() { post(.goBack) }
    func goForward() { post(.goForward) }
    func nextTab() { post(.nextTab) }
    func previousTab() { post(.previousTab) }
    func toggleSidebar() { post(.toggleSidebar) }
    func findInPage() { post(.findInPage) }
    func openDevTools() { post(.openDevTools) }
    func zoomIn() { post(.zoomIn) }
    func zoomOut() { post(.zoomOut) }
    func resetZoom() { post(.resetZoom) }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    // returns nil
    private func handle(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers?.lowercased()

        for shortcut in shortcuts {
            guard shortcut.modifiers == modifiers else { continue }
            let matches: Bool
            switch shortcut.trigger {
            case .character(let c): matches = chars == c
            case .keyCode(let code): matches = event.keyCode == code
            }
            if matches {
                post(shortcut.action)
                return nil
            }
        }
        return event
    }

    private func post(_ name: Notification.Name) {
        AppLog.ui("Shortcut fired: \(name.rawValue)")
        notificationCenter.post(name: name, object: nil)
    }
}

private extension Notification.Name {
    static let closeActiveTab = Notification.Name("closeActiveTab")
}


// TODO: Create an actual manager
final class BackgroundResourceManager {
    func start() {
        AppLog.info("BackgroundResourceManager started")
    }
}

// TODO: Replace logging stub with real integrity/policy checks.
final class RuntimeSecurityMonitor {

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func startMonitoring() {
        observe(.newTab) { AppLog.security("Runtime check passed for New Tab action") }
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
