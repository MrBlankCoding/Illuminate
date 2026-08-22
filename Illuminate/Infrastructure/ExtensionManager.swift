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
    
    private let userDefaults = UserDefaults.standard
    
    private var statesKey: String {
        if let id = profileID { return "illuminate.extension.states.\(id.uuidString)" }
        return "illuminate.extension.states.global"
    }
    
    private var extensionResourceURLs: [WKWebExtension: URL] = [:]
    
    private var tabManagers: Set<TabManager> = []
    
    private var extensionContextForURL: [URL: WKWebExtensionContext] = [:]
    
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

        let config: WKWebExtensionController.Configuration
        if isGuestSession {
            config = .nonPersistent()
            config.defaultWebsiteDataStore = .nonPersistent()
        } else if let profileID {
            config = .init(identifier: profileID)
            config.defaultWebsiteDataStore = WKWebsiteDataStore(forIdentifier: profileID)
        } else {
            config = .default()
        }
        self.controller = WKWebExtensionController(configuration: config)
        
        super.init()
        
        self.controller.delegate = self
        if !isGuestSession {
            loadPersistedExtensions()
        }
        loadBundledExtensions()
    }

    private func loadPersistedExtensions() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let records = try? JSONDecoder().decode([String: ExtensionRecord].self, from: data) else {
            return
        }
        
        for (identifier, record) in records {
            Task {
                do {
                    try await self.installExtension(
                        from: record.resourceURL,
                        preferredIdentifier: identifier,
                        initiallyEnabled: record.isEnabled,
                        persist: false
                    )
                } catch {
                    AppLog.error("Failed to restore extension from \(record.resourceURL): \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveInstalledExtensions() {
        guard !isGuestSession else { return }

        var records: [String: ExtensionRecord] = [:]
        
        for context in installedExtensions {
            let identifier = identifier(for: context)
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
            states[identifier(for: context)] = isEnabled(context)
        }
        userDefaults.set(states, forKey: statesKey)
    }

    func identifier(for context: WKWebExtensionContext) -> String {
        context.uniqueIdentifier
    }

    func matchesGalleryItem(_ item: ExtensionGalleryItem, context: WKWebExtensionContext) -> Bool {
        if identifier(for: context) == item.id {
            return true
        }
        let names = [context.webExtension.displayName, context.webExtension.displayShortName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return names.contains { $0.caseInsensitiveCompare(item.name) == .orderedSame }
    }

    private func loadBundledExtensions() {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL,
              FileManager.default.fileExists(atPath: pluginsURL.path) else {
            return
        }
        
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
        let identifier = identifier(for: context)
        if let states = userDefaults.dictionary(forKey: statesKey) as? [String: Bool] {
            return states[identifier] ?? true
        }
        return true
    }

    func setEnabled(_ context: WKWebExtensionContext, enabled: Bool) {
        let identifier = identifier(for: context)
        
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

    func installExtension(
        from url: URL,
        preferredIdentifier: String? = nil,
        initiallyEnabled: Bool = true,
        persist: Bool = true
    ) async throws {
        let shouldPersist = persist && !isGuestSession
        let stagingIdentifier = preferredIdentifier ?? UUID().uuidString
        let packageURL: URL
        if shouldPersist {
            packageURL = try persistPackage(from: url, identifier: stagingIdentifier)
        } else {
            packageURL = url
        }

        let extensionRepresentation = try await WKWebExtension(resourceBaseURL: packageURL)
        if !extensionRepresentation.errors.isEmpty {
            let details = extensionRepresentation.errors.map(\.localizedDescription).joined(separator: "; ")
            AppLog.error("Extension reported parse issues: \(details)")
        }

        let context = WKWebExtensionContext(for: extensionRepresentation)
        let newID = preferredIdentifier
            ?? extensionRepresentation.displayName?
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            ?? context.uniqueIdentifier
        context.uniqueIdentifier = newID
        grantRequiredPermissions(for: context)
        prepareRuntimeStorageDirectory(for: newID)

        let finalURL = packageURL

        var loadError: Error?
        await MainActor.run {
            self.extensionResourceURLs[extensionRepresentation] = finalURL
            
            if let existing = self.installedExtensions.first(where: { self.identifier(for: $0) == newID }) {
                try? self.controller.unload(existing)
                self.installedExtensions.removeAll { self.identifier(for: $0) == newID }
            }
            
            self.installedExtensions.append(context)
            if shouldPersist {
                var states = self.userDefaults.dictionary(forKey: self.statesKey) as? [String: Bool] ?? [:]
                states[newID] = initiallyEnabled
                self.userDefaults.set(states, forKey: self.statesKey)
            }
            
            if initiallyEnabled {
                do {
                    try self.controller.load(context)
                } catch {
                    loadError = error
                    AppLog.error("Failed to load installed extension: \(error.localizedDescription)")
                }
            }
            
            if shouldPersist {
                self.saveInstalledExtensions()
            }
        }

        if let loadError {
            throw NSError(
                domain: "ExtensionManager",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "The extension was copied but could not be loaded: \(loadError.localizedDescription)"]
            )
        }
    }

    private func grantRequiredPermissions(for context: WKWebExtensionContext) {
        let neverExpires = Date.distantFuture
        var permissions: [WKWebExtension.Permission: Date] = [:]
        for permission in context.webExtension.requestedPermissions {
            permissions[permission] = neverExpires
        }
        context.grantedPermissions = permissions

        var patterns: [WKWebExtension.MatchPattern: Date] = [:]
        for pattern in context.webExtension.requestedPermissionMatchPatterns {
            patterns[pattern] = neverExpires
        }
        for pattern in context.webExtension.allRequestedMatchPatterns {
            patterns[pattern] = neverExpires
        }
        context.grantedPermissionMatchPatterns = patterns
        context.hasAccessToPrivateData = isGuestSession
    }

    private func persistPackage(from url: URL, identifier: String) throws -> URL {
        try FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true)
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? url.hasDirectoryPath
        let targetURL: URL
        if isDirectory == true {
            targetURL = extensionsDirectory.appendingPathComponent(identifier, isDirectory: true)
        } else {
            let ext = url.pathExtension.isEmpty ? "zip" : url.pathExtension
            targetURL = extensionsDirectory.appendingPathComponent("\(identifier).\(ext)")
        }
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: url, to: targetURL)
        return targetURL
    }

    private func prepareRuntimeStorageDirectory(for uniqueIdentifier: String) {
        guard !isGuestSession else { return }
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }

        var directory = library
            .appendingPathComponent("WebKit", isDirectory: true)
            .appendingPathComponent("WebExtensions", isDirectory: true)
        if let profileID {
            directory = directory.appendingPathComponent(profileID.uuidString, isDirectory: true)
        }
        directory = directory.appendingPathComponent(uniqueIdentifier, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    func uninstallExtension(_ context: WKWebExtensionContext) {
        try? controller.unload(context)
        
        let id = identifier(for: context)
        var states = userDefaults.dictionary(forKey: statesKey) as? [String: Bool] ?? [:]
        states.removeValue(forKey: id)
        userDefaults.set(states, forKey: statesKey)
        
        let targetURL = extensionsDirectory.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.removeItem(at: targetURL)
        if let url = extensionResourceURLs[context.webExtension] {
            try? FileManager.default.removeItem(at: url)
            extensionResourceURLs.removeValue(forKey: context.webExtension)
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
        let urls: Set<URL>?
        let completion: (Bool) -> Void
    }
}

extension ExtensionManager: WKWebExtensionControllerDelegate {
    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor context: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        var windows = Array(tabManagers)
        if let active = activeTabManager, let index = windows.firstIndex(where: { $0 === active }) {
            windows.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
        }
        return windows
    }

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
        
        // Store the extension context for this URL so it can be used when the tab is created
        if let url = configuration.url {
            extensionContextForURL[url] = context
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
        
        // Store the extension context for this URL so we can use it when the tab is created
        // This is a workaround for the extension URL loading issue
        extensionContextForURL[url] = context
        
        NotificationCenter.default.post(name: .openURL, object: url)
        completionHandler(nil)
    }
    
    func getExtensionContext(for url: URL) -> WKWebExtensionContext? {
        return extensionContextForURL[url]
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>, in tab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void) {
        activePermissionRequest = PermissionRequest(
            context: context,
            permissions: permissions,
            matchPatterns: nil,
            urls: nil,
            completion: { granted in
                completionHandler(granted ? permissions : [], nil)
            }
        )
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>, in tab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void) {
        activePermissionRequest = PermissionRequest(
            context: context,
            permissions: nil,
            matchPatterns: matchPatterns,
            urls: nil,
            completion: { granted in
                completionHandler(granted ? matchPatterns : [], nil)
            }
        )
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext, completionHandler: @escaping (Set<URL>, Date?) -> Void) {
        activePermissionRequest = PermissionRequest(
            context: context,
            permissions: nil,
            matchPatterns: nil,
            urls: urls,
            completion: { granted in
                completionHandler(granted ? urls : [], nil)
            }
        )
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, didUpdate action: WKWebExtension.Action, forExtensionContext context: WKWebExtensionContext) {
        actionChanges.send((context, action.associatedTab))
    }
}
