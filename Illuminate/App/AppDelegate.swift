//
//  AppDelegate.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import AppKit
import SwiftUI

@MainActor
final class DockMenuWindowRouter {
    static let shared = DockMenuWindowRouter()

    var openProfileSelection: (() -> Void)?
    var openProfile: ((UUID) -> Void)?
    var openGuest: (() -> Void)?

    private init() {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        observeExtensionWindowRequests()
        prewarmSessionStateFiles()

        guard isRunningUITests() else { return }
        Task { @MainActor in
            await bringAppToFrontForUITests()
        }
    }

    private func prewarmSessionStateFiles() {
        let profileID = lastUsedOrFirstProfileID()
        StateFilePrefetcher.prefetch([
            TabManager.makeSessionURL(profileID: profileID),
            TabGroupManager.makeGroupsURL(profileID: profileID),
            FileManager.default.illuminateProfilesCatalogURL(),
        ])
    }

    private func observeExtensionWindowRequests() {
        NotificationCenter.default.addObserver(
            forName: .openNewWindowFromExtension, object: nil, queue: .main
        ) { [weak self] _ in
            self?.openProfileWindowForExtension()
        }
    }

    private func openProfileWindowForExtension() {
        if let profileID = lastUsedOrFirstProfileID() {
            DockMenuWindowRouter.shared.openProfile?(profileID)
        } else {
            // No profiles exist (first launch) — fall back to a guest window.
            DockMenuWindowRouter.shared.openGuest?()
        }
    }

    private func lastUsedOrFirstProfileID() -> UUID? {
        let defaults = UserDefaults.standard
        if let rawID = defaults.string(forKey: ProfileManager.lastUsedProfileKey),
           let profileID = UUID(uuidString: rawID) {
            return profileID
        }
        return fetchProfiles().first?.id
    }

    private func isRunningUITests() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        let env  = ProcessInfo.processInfo.environment
        return args.contains(where: { $0.caseInsensitiveCompare("-uiTesting") == .orderedSame })
            || env["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            PasskeyAuthorizationService.shared.requestAccessIfNeeded()
        }
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let profiles = fetchProfiles()
        for profile in profiles {
            let item = NSMenuItem(title: "Open \(profile.name)", action: #selector(openProfile(_:)), keyEquivalent: "")
            item.representedObject = profile.id.uuidString
            menu.addItem(item)
        }

        let newWindowItem = NSMenuItem(title: "New Profile Window", action: #selector(openNewWindow(_:)), keyEquivalent: "")
        menu.addItem(newWindowItem)

        let newGuestWindowItem = NSMenuItem(title: "New Guest Window", action: #selector(openNewGuestWindow(_:)), keyEquivalent: "")
        menu.addItem(newGuestWindowItem)

        return menu
    }
    
    @objc func openProfile(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)

        if let idString = sender.representedObject as? String,
           let profileID = UUID(uuidString: idString) {
            if let openProfile = DockMenuWindowRouter.shared.openProfile {
                openProfile(profileID)
            } else {
                AppLog.ui("Warning: openProfile closure not registered.")
                DockMenuWindowRouter.shared.openProfileSelection?()
            }
        }
    }
    
    @objc func openNewWindow(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        if let openSelection = DockMenuWindowRouter.shared.openProfileSelection {
            openSelection()
        } else {
            AppLog.ui("Warning: openProfileSelection closure not registered.")
        }
    }

    @objc func openNewGuestWindow(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        if let openGuest = DockMenuWindowRouter.shared.openGuest {
            openGuest()
        } else {
            AppLog.ui("Warning: openGuest closure not registered.")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    // OPEN FILES
    // yo files are cool
    // but what if its unsafe
    // protection? 
    // TODO

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        handleOpenedFiles([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handleOpenedFiles(urls)
    }

    private func handleOpenedFiles(_ urls: [URL]) {
        Task { @MainActor in
            for url in urls where !url.isFileURL {
                WebURLOpening.shared.handle(url)
            }

            let files = urls.filter { $0.isFileURL }
            let hadWindowBefore = BrowserWindowRegistry.shared.activeCount > 0
            for url in files { AppFileOpening.shared.enqueue(url) }
            if !files.isEmpty && !hadWindowBefore {
                AppFileOpening.shared.markNeedsBrowserWindow()
            }
        }
    }

    private func fetchProfiles() -> [BrowserProfile] {
        let catalogURL = FileManager.default.illuminateProfilesCatalogURL()
        let data = StateFilePrefetcher.consume(catalogURL) ?? (try? Data(contentsOf: catalogURL))
        guard let data,
              let profiles = try? JSONDecoder().decode([BrowserProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    private func bringAppToFrontForUITests() async {
        for _ in 0..<10 {
            NSApp.activate(ignoringOtherApps: true)

            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }

            if NSApp.windows.contains(where: \.isVisible) {
                return
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
