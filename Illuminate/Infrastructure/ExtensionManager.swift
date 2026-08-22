//
//  ExtensionManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/21/26.
//

import Foundation
import WebKit
import SwiftUI
import Combine

@MainActor
final class ExtensionManager: NSObject, ObservableObject {
    @Published private(set) var installedExtensions: [WKWebExtensionContext] = []
    
    let controller: WKWebExtensionController
    let profileID: UUID?
    let isGuestSession: Bool
    
    private var extensionStates: [String: Bool] = [:] // bundleID or uniqueID: isEnabled
    private let userDefaults = UserDefaults.standard
    
    private var statesKey: String {
        if let id = profileID { return "illuminate.extension.states.\(id.uuidString)" }
        return "illuminate.extension.states.global"
    }
    
    private var extensionResourceURLs: [WKWebExtension: URL] = [:]
    
    private var tabManagers: Set<TabManager> = []
    
    var activeTabManager: TabManager? {
        tabManagers.first { $0.isFocused } ?? tabManagers.first
    }
    
    private var persistenceURL: URL {
        let fileName = profileID.map { "extensions-\($0.uuidString).json" } ?? "extensions-global.json"
        return FileManager.default.illuminateAppSupportDirectory().appendingPathComponent(fileName)
    }

    struct ExtensionRecord: Codable {
        let resourceURL: URL
        let isEnabled: Bool
    }

    init(profileID: UUID?, isGuestSession: Bool = false) {
        self.profileID = profileID
        self.isGuestSession = isGuestSession
        
        let identifier = profileID.map { "illuminate.extensions.\($0.uuidString)" } ?? "illuminate.extensions.global"
        let config = WKWebExtensionController.Configuration.default()
        self.controller = WKWebExtensionController(configuration: config)
        
        super.init()
        
        self.controller.delegate = self
        loadPersistedExtensions()
        loadBundledExtensions()
    }

    private func loadPersistedExtensions() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let records = try? JSONDecoder().decode([String: ExtensionRecord].self, from: data) else {
            return
        }
        
        for (_, record) in records {
            Task {
                do {
                    try await self.installExtension(from: record.resourceURL, initiallyEnabled: record.isEnabled, persist: false)
                } catch {
                    AppLog.error("Failed to restore extension from \(record.resourceURL): \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveInstalledExtensions() {
        var records: [String: ExtensionRecord] = [:]
        
        for context in installedExtensions {
            guard let identifier = identifier(for: context) else { continue }
            
            let isBundled = context.webExtension.manifest["__bundled__"] as? Bool ?? false
            
            if !isBundled {
                if let url = extensionResourceURLs[context.webExtension] {
                    records[identifier] = ExtensionRecord(resourceURL: url, isEnabled: isEnabled(context))
                }
            }
        }
        
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: persistenceURL)
        }
        
        var states: [String: Bool] = [:]
        for context in installedExtensions {
            if let id = identifier(for: context) {
                states[id] = isEnabled(context)
            }
        }
        userDefaults.set(states, forKey: statesKey)
    }

    private func identifier(for context: WKWebExtensionContext) -> String? {
        if let manifestID = context.webExtension.manifest["id"] as? String {
            return manifestID
        }
        
        if let displayName = context.webExtension.displayName {
            let version = context.webExtension.version ?? "1.0"
            let safeName = displayName.lowercased().replacingOccurrences(of: " ", with: ".")
            return "\(safeName)-\(version)"
        }
        return nil
    }

    private func loadBundledExtensions() {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL else { return }
        
        do {
            let pluginURLs = try FileManager.default.contentsOfDirectory(at: pluginsURL, includingPropertiesForKeys: nil)
            for url in pluginURLs where url.pathExtension == "appex" {
                guard let bundle = Bundle(url: url) else { continue }
                Task {
                    do {
                        let extensionRepresentation = try await WKWebExtension(appExtensionBundle: bundle)
                        let context = WKWebExtensionContext(for: extensionRepresentation)
                        
                        await MainActor.run {
                            if !self.installedExtensions.contains(where: { self.identifier(for: $0) == self.identifier(for: context) }) {
                                self.installedExtensions.append(context)
                                if self.isEnabled(context) {
                                    do {
                                        try self.controller.load(context)
                                    } catch {
                                        AppLog.error("Failed to load bundled extension: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    } catch {
                        AppLog.error("Failed to create WKWebExtension for \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            AppLog.error("Failed to scan PlugIns directory: \(error.localizedDescription)")
        }
    }

    func isEnabled(_ context: WKWebExtensionContext) -> Bool {
        guard let identifier = identifier(for: context) else { return true }
        if let states = userDefaults.dictionary(forKey: statesKey) as? [String: Bool] {
            return states[identifier] ?? true
        }
        return true
    }

    func setEnabled(_ context: WKWebExtensionContext, enabled: Bool) {
        guard let identifier = identifier(for: context) else { return }
        
        var states = userDefaults.dictionary(forKey: statesKey) as? [String: Bool] ?? [:]
        states[identifier] = enabled
        userDefaults.set(states, forKey: statesKey)
        
        if enabled {
            do {
                try controller.load(context)
            } catch {
                AppLog.error("Failed to load extension context: \(error.localizedDescription)")
            }
        } else {
            try? controller.unload(context)
        }
        
        saveInstalledExtensions()
        objectWillChange.send()
    }

    private var extensionsDirectory: URL {
        let dirName = profileID.map { "InstalledExtensions-\($0.uuidString)" } ?? "InstalledExtensions-Global"
        return FileManager.default.illuminateAppSupportDirectory().appendingPathComponent(dirName, isDirectory: true)
    }

    func installExtension(from url: URL, initiallyEnabled: Bool = true, persist: Bool = true) async throws {
        let extensionRepresentation = try await WKWebExtension(resourceBaseURL: url)
        let context = WKWebExtensionContext(for: extensionRepresentation)
        
        guard let newID = self.identifier(for: context) else {
            throw NSError(domain: "ExtensionManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid extension identifier"])
        }
        
        let targetURL = extensionsDirectory.appendingPathComponent(newID, isDirectory: true)
        
        var finalURL = url
        if persist {
            try? FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: url, to: targetURL)
            finalURL = targetURL
        }

        await MainActor.run {
            self.extensionResourceURLs[extensionRepresentation] = finalURL
            
            if let existing = self.installedExtensions.first(where: { self.identifier(for: $0) == newID }) {
                try? self.controller.unload(existing)
                self.installedExtensions.removeAll { self.identifier(for: $0) == newID }
            }
            
            self.installedExtensions.append(context)
            if persist {
                var states = self.userDefaults.dictionary(forKey: self.statesKey) as? [String: Bool] ?? [:]
                states[newID] = initiallyEnabled
                self.userDefaults.set(states, forKey: self.statesKey)
            }
            
            if initiallyEnabled {
                do {
                    try self.controller.load(context)
                } catch {
                    AppLog.error("Failed to load installed extension: \(error.localizedDescription)")
                }
            }
            
            if persist {
                self.saveInstalledExtensions()
            }
        }
    }
    
    func uninstallExtension(_ context: WKWebExtensionContext) {
        try? controller.unload(context)
        
        if let id = identifier(for: context) {
            var states = userDefaults.dictionary(forKey: statesKey) as? [String: Bool] ?? [:]
            states.removeValue(forKey: id)
            userDefaults.set(states, forKey: statesKey)
            
            let targetURL = extensionsDirectory.appendingPathComponent(id, isDirectory: true)
            try? FileManager.default.removeItem(at: targetURL)
        }
        
        installedExtensions.removeAll { $0 === context }
        saveInstalledExtensions()
    }

    private var pendingWindowCompletions: [(WKWebExtensionWindow?, (any Error)?) -> Void] = []
    
    func registerTabManager(_ tabManager: TabManager) {
        tabManagers.insert(tabManager)
        if !pendingWindowCompletions.isEmpty {
            let completion = pendingWindowCompletions.removeFirst()
            completion(tabManager, nil)
        }
    }
    
    func unregisterTabManager(_ tabManager: TabManager) {
        tabManagers.remove(tabManager)
    }

    func unregisterTabManager(withIdentifier identifier: ObjectIdentifier) {
        if let manager = tabManagers.first(where: { ObjectIdentifier($0) == identifier }) {
            tabManagers.remove(manager)
        }
    }
    
    @Published var activePermissionRequest: PermissionRequest?
    
    let actionChanges = PassthroughSubject<(WKWebExtensionContext, (any WKWebExtensionTab)?), Never>()
    
    struct PermissionRequest: Identifiable {
        let id = UUID()
        let context: WKWebExtensionContext
        let permissions: Set<WKWebExtension.Permission>?
        let matchPatterns: Set<WKWebExtension.MatchPattern>?
        let completion: (Bool) -> Void
    }
}

extension ExtensionManager: WKWebExtensionControllerDelegate {
    func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration, for context: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void) {
        let targetTabManager: TabManager?
        
        if let targetWindow = configuration.window as? TabManager {
            targetTabManager = targetWindow
        } else {
            targetTabManager = activeTabManager
        }
        
        guard let tabManager = targetTabManager else {
            completionHandler(nil, NSError(domain: "ExtensionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active window found"]))
            return
        }
        
        let tab = tabManager.createTab(url: configuration.url, inBackground: !configuration.shouldBeActive)
        
        if let parentTab = configuration.parentTab as? Tab {
            tab.parentTab = parentTab
        }
        
        let index = configuration.index
        let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == tab.id }) ?? tabManager.tabs.count - 1
        if index != currentIndex && index >= 0 && index < tabManager.tabs.count {
            tabManager.moveTab(fromOffsets: IndexSet(integer: currentIndex), toOffset: index)
        }
        
        completionHandler(tab, nil)
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, openNewWindowUsing configuration: WKWebExtension.WindowConfiguration, for context: WKWebExtensionContext, completionHandler: @escaping (WKWebExtensionWindow?, (any Error)?) -> Void) {
        pendingWindowCompletions.append(completionHandler)
        
        let firstURL = configuration.tabs.first?.url
        NotificationCenter.default.post(name: NSNotification.Name("app.openNewWindow"), object: firstURL)
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor context: WKWebExtensionContext) -> WKWebExtensionWindow? {
        activeTabManager
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        guard let url = context.optionsPageURL else {
            completionHandler(NSError(domain: "ExtensionManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Options page not defined in manifest"]))
            return
        }
        
        NotificationCenter.default.post(name: .openURL, object: url)
        completionHandler(nil)
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>, in tab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.Permission>) -> Void) {
        activePermissionRequest = PermissionRequest(
            context: context,
            permissions: permissions,
            matchPatterns: nil,
            completion: { granted in
                completionHandler(granted ? permissions : [])
            }
        )
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>, in tab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.MatchPattern>) -> Void) {
        activePermissionRequest = PermissionRequest(
            context: context,
            permissions: nil,
            matchPatterns: matchPatterns,
            completion: { granted in
                completionHandler(granted ? matchPatterns : [])
            }
        )
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, didChange action: WKWebExtension.Action, for context: WKWebExtensionContext, in tab: (any WKWebExtensionTab)?) {
        actionChanges.send((context, tab))
    }
}
