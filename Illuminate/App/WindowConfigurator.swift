//
//  WindowConfigurator.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import AppKit
import WebKit

struct WindowConfigurator: NSViewRepresentable {
    @Environment(TabManager.self) var tabManager: TabManager
    @Environment(ProfileEnvironment.self) var profileEnvironment: ProfileEnvironment

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tabManager: tabManager,
            extensionManager: profileEnvironment.extensionManager,
            route: profileEnvironment.windowRoute
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        if let window = view.window,
           context.coordinator.window !== window {
            context.coordinator.window = window
            tabManager.window = window
            WebURLOpening.shared.register(tabManager)
            if !context.coordinator.didConfigure {
                context.coordinator.didConfigure = true
                configure(window: window)
            }
            update(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }

        if context.coordinator.window !== window {
            context.coordinator.window = window
            tabManager.window = window
            WebURLOpening.shared.register(tabManager)
        }

        if !context.coordinator.didConfigure {
            context.coordinator.didConfigure = true
            configure(window: window)
        }

        update(window: window)
    }

    private func configure(window: NSWindow) {
        NSApp.presentationOptions = []
        NSWindow.allowsAutomaticWindowTabbing = false

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.toolbar = nil
        window.titlebarSeparatorStyle = .none
    }

    private func update(window: NSWindow) {
        let trimmedTitle = tabManager.activeTab?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (trimmedTitle?.isEmpty == false ? trimmedTitle : nil) ?? "Illuminate"
        if window.title != title {
            window.title = title
        }
        window.representedURL = tabManager.activeTab?.url
    }

    class Coordinator: NSObject, NSWindowDelegate {
        var didConfigure = false
        weak var tabManager: TabManager?
        weak var extensionManager: ExtensionManager?
        let route: BrowserWindowRoute
        weak var window: NSWindow? {
            didSet {
                guard window !== oldValue else { return }
                if let oldValue { BrowserWindowRegistry.shared.unregister(oldValue) }
                if let window { BrowserWindowRegistry.shared.register(window, route: route) }
                window?.delegate = self
            }
        }

        init(tabManager: TabManager, extensionManager: ExtensionManager, route: BrowserWindowRoute) {
            self.tabManager = tabManager
            self.extensionManager = extensionManager
            self.route = route
        }

        func windowWillStartLiveResize(_ notification: Notification) {
            tabManager?.isResizing = true
        }

        func windowDidEndLiveResize(_ notification: Notification) {
            tabManager?.isResizing = false
        }
        
        func windowDidEnterFullScreen(_ notification: Notification) {
            tabManager?.isFullScreen = true
        }

        func windowDidExitFullScreen(_ notification: Notification) {
            tabManager?.isFullScreen = false
        }

        func windowDidBecomeKey(_ notification: Notification) {
            guard let tabManager, let extensionManager else { return }
            extensionManager.controller.didFocusWindow(tabManager)
        }

        func windowWillClose(_ notification: Notification) {
            if let closingWindow = notification.object as? NSWindow {
                BrowserWindowRegistry.shared.unregister(closingWindow)
            }
            guard let tabManager else { return }
            WebURLOpening.shared.unregister(tabManager)
        }

        func windowDidResignKey(_ notification: Notification) {
            // careful around this...
            // hi
            // idk what to put here
        }
    }
}
