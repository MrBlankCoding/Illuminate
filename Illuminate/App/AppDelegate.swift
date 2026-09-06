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

    @MainActor
    var profileSelectionWasExplicitlyRequested: Bool = false

    private init() {}

    func requestProfileSelection(open: @escaping () -> Void) {
        profileSelectionWasExplicitlyRequested = true
        open()
    }

    func consumeExplicitProfileSelectionRequest() -> Bool {
        defer { profileSelectionWasExplicitlyRequested = false }
        return profileSelectionWasExplicitlyRequested
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    static let warnBeforeQuittingKey = "warnBeforeQuittingEnabled"

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.info("AppDelegate: applicationDidFinishLaunching (uiTesting=\(isRunningUITests()))")
        _ = BrowserImagePipeline.shared
        observeExtensionWindowRequests()
        prewarmSessionStateFiles()
        WebKitManager.cleanupContainersIfNeeded()

        for profile in fetchProfiles() {
            ContainerCleanup.cleanupWebsiteDataStore(for: profile.id)
        }

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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UserDefaults.standard.bool(forKey: Self.warnBeforeQuittingKey) else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Quit Illuminate?"
        alert.informativeText = "Are you sure you want to quit? All open tabs will be closed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
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
        for _ in 0..<30 {
            NSApp.activate(ignoringOtherApps: true)

            for window in NSApp.windows where !window.className.contains("StatusBar") {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }

            if NSApp.windows.contains(where: { $0.isVisible && !$0.className.contains("StatusBar") && !windowClassNameIsInternal($0) }) {
                return
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func windowClassNameIsInternal(_ window: NSWindow) -> Bool {
        let name = window.className
        return name.contains("StatusBar") || name.contains("Menu") || name.contains("Panel")
    }
}

private var unsavedChangesDelegateKey: UInt8 = 0

final class UnsavedChangesWindowDelegate: NSObject, NSWindowDelegate {
    var hasDirtyTabs: (() -> Bool)?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let hasDirtyTabs, hasDirtyTabs() else { return true }

        let alert = NSAlert()
        alert.messageText = "Leave this page?"
        alert.informativeText = "You have unsaved changes that may be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Leave")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }
}

func installUnsavedChangesInterceptor(on window: NSWindow) {
    let delegate = UnsavedChangesWindowDelegate()
    objc_setAssociatedObject(window, &unsavedChangesDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
    window.delegate = delegate
}
