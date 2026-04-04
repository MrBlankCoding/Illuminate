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

    private init() {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard UITestLaunchConfiguration.isRunningUITests else {
            return
        }

        Task { @MainActor in
            await bringAppToFrontForUITests()
        }
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        
        // Quickly read profiles from disk
        let manager = FileManager.default
        let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fullPath = appSupport.appendingPathComponent("Illuminate").appendingPathComponent("profiles.json")
        
        if let data = try? Data(contentsOf: fullPath),
           let profiles = try? JSONDecoder().decode([BrowserProfile].self, from: data) {
            
            for profile in profiles {
                let item = NSMenuItem(title: "Open \(profile.name)", action: #selector(openProfile(_:)), keyEquivalent: "")
                item.representedObject = profile.id.uuidString
                menu.addItem(item)
            }
        }
        
        let newWindowItem = NSMenuItem(title: "New Profile Window", action: #selector(openNewWindow(_:)), keyEquivalent: "")
        menu.addItem(newWindowItem)
        
        return menu
    }
    
    @objc func openProfile(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)

        if let idString = sender.representedObject as? String,
           let profileID = UUID(uuidString: idString) {
            DockMenuWindowRouter.shared.openProfile?(profileID)
        }
    }
    
    @objc func openNewWindow(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        DockMenuWindowRouter.shared.openProfileSelection?()
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
