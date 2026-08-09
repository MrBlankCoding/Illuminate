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
        logPersistedSettings()

        guard UITestLaunchConfiguration.isRunningUITests else {
            return
        }

        Task { @MainActor in
            await bringAppToFrontForUITests()
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
                // Fallback: try triggering selection
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
        // If no windows are visible, return true to let SwiftUI open the default window group.
        // This is safer than manual routing and avoids the URL registration issues.
        return true
    }

    private func fetchProfiles() -> [BrowserProfile] {
        let catalogURL = FileManager.default.illuminateProfilesCatalogURL()

        guard let data = try? Data(contentsOf: catalogURL),
              let profiles = try? JSONDecoder().decode([BrowserProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    private func logPersistedSettings() {
        AppLog.info("--- Persisted settings at launch ---")

        let defaults = UserDefaults.standard
        let tabManagerKeys = [
            "windowThemeColor",
            "backgroundImageURL",
            "showSidebar",
            "showBackgroundBehindSidebar",
            "userInterfaceStyle"
        ]

        let profileIDs = self.fetchProfiles().map { $0.id.uuidString }

        if profileIDs.isEmpty {
            AppLog.info("No profiles found.")
        } else {
            profileIDs.forEach { profileID in
                AppLog.info("Profile settings for \(profileID):")
                logProfileStringSetting(
                    defaults: defaults,
                    profileID: profileID,
                    key: "windowThemeColor",
                    defaultValue: "89BBFF"
                )
                logProfileStringSetting(
                    defaults: defaults,
                    profileID: profileID,
                    key: "backgroundImageURL",
                    defaultValue: ""
                )
                logProfileBoolSetting(
                    defaults: defaults,
                    profileID: profileID,
                    key: "showSidebar",
                    defaultValue: true
                )
                logProfileBoolSetting(
                    defaults: defaults,
                    profileID: profileID,
                    key: "showBackgroundBehindSidebar",
                    defaultValue: true
                )
                logProfileStringSetting(
                    defaults: defaults,
                    profileID: profileID,
                    key: "userInterfaceStyle",
                    defaultValue: "dark"
                )

                logProfileBoolSetting(
                    defaults: defaults,
                    profileID: profileID,
                    key: "adBlockEnabled",
                    defaultValue: true
                )
                logProfileBoolSetting(
                    defaults: defaults,
                    profileID: profileID,
                    key: "cookiesEnabled",
                    defaultValue: true
                )
            }
        }

        let adBlockEnabled = defaults.object(forKey: "adBlockEnabled") as? Bool ?? true
        let cookiesEnabled = defaults.object(forKey: "cookiesEnabled") as? Bool ?? true
        let downloadPreferencesData = defaults.data(forKey: "download.preferences")

        AppLog.info("General settings:")
        AppLog.info("  adBlockEnabled = \(adBlockEnabled)")
        AppLog.info("  cookiesEnabled = \(cookiesEnabled)")
        AppLog.info("  download.preferences present = \(downloadPreferencesData != nil)")
        AppLog.info("--- End persisted settings ---")
    }

    private func logProfileStringSetting(defaults: UserDefaults, profileID: String, key: String, defaultValue: String) {
        let scopedKey = "profile.\(profileID).\(key)"
        let value = defaults.string(forKey: scopedKey) ?? defaultValue
        AppLog.info("  \(scopedKey) = \(value)")
    }

    private func logProfileBoolSetting(defaults: UserDefaults, profileID: String, key: String, defaultValue: Bool) {
        let scopedKey = "profile.\(profileID).\(key)"
        let value = defaults.object(forKey: scopedKey) as? Bool ?? defaultValue
        AppLog.info("  \(scopedKey) = \(value)")
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
