//
//  AppDelegate.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
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
        if let idString = sender.representedObject as? String {
            if let url = URL(string: "illuminate://profile/\(idString)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc func openNewWindow(_ sender: NSMenuItem) {
        if let url = URL(string: "illuminate://new") {
            NSWorkspace.shared.open(url)
        }
    }
}
