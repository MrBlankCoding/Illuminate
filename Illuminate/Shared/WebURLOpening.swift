//
//  WebURLOpening.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/27/26.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class WebURLOpening {
    static let shared = WebURLOpening()

    private(set) var queuedURLs: [URL] = []
    var needsBrowserWindow = false

    @ObservationIgnored private var registrations: [ObjectIdentifier: Registration] = [:]
    @ObservationIgnored private var registrationOrder: [ObjectIdentifier] = []

    private struct Registration {
        let tabManager: TabManager
        var registeredAt: UInt64
    }

    private var nextSequence: UInt64 = 0

    private init() {}

    func register(_ tabManager: TabManager) {
        let id = ObjectIdentifier(tabManager)
        nextSequence &+= 1
        registrations[id] = Registration(tabManager: tabManager, registeredAt: nextSequence)
        registrationOrder.removeAll { $0 == id }
        registrationOrder.append(id)

        drainIfNeeded(into: tabManager)
    }

    func unregister(_ tabManager: TabManager) {
        let id = ObjectIdentifier(tabManager)
        registrations.removeValue(forKey: id)
        registrationOrder.removeAll { $0 == id }
    }

    func handle(_ url: URL) {
        guard isNavigable(url) else { return }
        if let target = frontmostTabManager() {
            NSApp.activate(ignoringOtherApps: true)
            target.window?.makeKeyAndOrderFront(nil)
            target.createTab(url: url)
        } else {
            queuedURLs.append(url)
            needsBrowserWindow = true
        }
    }

    func drainIfNeeded(into tabManager: TabManager) {
        guard !queuedURLs.isEmpty else { return }
        let urls = queuedURLs
        queuedURLs.removeAll()
        needsBrowserWindow = false

        // If this window was freshly opened specifically to serve these queued
        // URLs, drop the auto-created blank "New Tab" so the user lands on the
        // link instead of a blank start/profile page.
        let placeholderID = tabManager.consumePristineBlankTabForExternalOpen()

        for url in urls {
            tabManager.createTab(url: url)
        }

        if let placeholderID {
            tabManager.closeTab(id: placeholderID)
        }

        // Bring the browser window to front so the opened link isn't left running
        // in the background behind a start/profile window.
        NSApp.activate(ignoringOtherApps: true)
        tabManager.window?.makeKeyAndOrderFront(nil)
    }

    // testing only
    func resetForTesting() {
        registrations.removeAll()
        registrationOrder.removeAll()
        queuedURLs.removeAll()
        needsBrowserWindow = false
    }

    private func frontmostTabManager() -> TabManager? {
        let ordered = NSApp.orderedWindows
        for window in ordered where window.isVisible {
            for id in registrationOrder {
                guard let registration = registrations[id] else { continue }
                if registration.tabManager.window === window {
                    return registration.tabManager
                }
            }
        }

        guard let newest = registrationOrder.last, let registration = registrations[newest] else {
            return nil
        }
        return registration.tabManager
    }

    private func isNavigable(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https":
            return true
        default:
            return false
        }
    }
}
