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
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var profileEnvironment: ProfileEnvironment

    func makeCoordinator() -> Coordinator { Coordinator(tabManager: tabManager, extensionManager: profileEnvironment.extensionManager) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let view, let window = view.window,
                  !context.coordinator.didConfigure else { return }
            context.coordinator.didConfigure = true
            context.coordinator.window = window
            tabManager.window = window
            WebURLOpening.shared.register(tabManager)
            configure(window: window)
            update(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else { return }
            if context.coordinator.window !== window {
                context.coordinator.window = window
                tabManager.window = window
                WebURLOpening.shared.register(tabManager)
                if !context.coordinator.didConfigure {
                    context.coordinator.didConfigure = true
                    configure(window: window)
                }
            }
            update(window: window)
        }
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
        weak var window: NSWindow? {
            didSet {
                window?.delegate = self
            }
        }

        init(tabManager: TabManager, extensionManager: ExtensionManager) {
            self.tabManager = tabManager
            self.extensionManager = extensionManager
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
