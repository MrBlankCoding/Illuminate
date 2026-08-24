//
//  ExtensionManager.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/8/26.
//


import Foundation
import WebKit
import SwiftUI
import Combine

private final class LRUCache<Key: Hashable, Value> {
    private var store: [Key: Value] = [:]
    private var order: [Key] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func value(for key: Key) -> Value? {
        guard let value = store[key] else { return nil }
        touch(key)
        return value
    }

    func insert(_ value: Value, for key: Key) {
        if store[key] != nil {
            store[key] = value
            touch(key)
            return
        }
        if store.count >= capacity {
            if let oldest = order.first {
                order.removeFirst()
                store.removeValue(forKey: oldest)
            }
        }
        store[key] = value
        order.append(key)
    }

    func removeValue(for key: Key) {
        guard store[key] != nil else { return }
        store.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }

    func removeAll() {
        store.removeAll()
        order.removeAll()
    }

    func removeAll(where predicate: (Value) -> Bool) {
        let keysToRemove = store.filter { predicate($0.value) }.map(\.key)
        for key in keysToRemove { removeValue(for: key) }
    }

    private func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}

@MainActor
final class ExtensionManager: NSObject, ObservableObject {
    @Published private(set) var installedExtensions: [WKWebExtensionContext] = []
    @Published private(set) var isLoadingExtensions: Bool = false
    @Published private(set) var loadingErrors: [ExtensionLoadingError] = []
    @Published private(set) var enabledStateVersion: Int = 0
    @Published private(set) var pendingUpdateCount: Int = 0
    @Published private(set) var isCheckingForUpdates: Bool = false
    @Published private(set) var pinnedExtensions: Set<String> = []

    @Published var activePermissionRequest: PermissionRequest?

    let actionChanges = PassthroughSubject<(WKWebExtensionContext, (any WKWebExtensionTab)?), Never>()
    let controller: WKWebExtensionController
    let profileID: UUID?
    let isGuestSession: Bool

    private var bundledExtensionIdentifiers: Set<String> = []
    private let userDefaults = UserDefaults.standard
    private var extensionStatesCache: [String: Bool] = [:]

    private var statesKey: String {
        if let id = profileID { return "illuminate.extension.states.\(id.uuidString)" }
        return "illuminate.extension.states.global"
    }

    private var pinnedExtensionsKey: String {
        if let id = profileID { return "illuminate.extension.pinned.\(id.uuidString)" }
        return "illuminate.extension.pinned.global"
    }

    private var extensionResourceURLs: [WKWebExtension: URL] = [:]
    private var tabManagers: Set<TabManager> = []
    private var extensionContextCache = LRUCache<URL, WKWebExtensionContext>(capacity: 128)
    private var loadingTask: Task<Void, Never>?
    private var extensionSources: [String: ExtensionPackageSource] = [:]
    private var autoUpdateTask: Task<Void, Never>?
    private static let autoUpdateInterval: TimeInterval = 86_400
    private struct PendingWindow {
        let id: UUID
        let completion: (WKWebExtensionWindow?, (any Error)?) -> Void
        let timeoutTask: Task<Void, Never>
    }
    private var pendingWindows: [UUID: PendingWindow] = [:]
    private var permissionRequestTimeoutTask: Task<Void, Never>?

    private var persistenceURL: URL {
        let fileName = profileID.map { "extensions-\($0.uuidString).json" } ?? "extensions-global.json"
        return FileManager.default.illuminateAppSupportDirectory().appendingPathComponent(fileName)
    }

    private var extensionsDirectory: URL {
        let dirName = profileID.map { "InstalledExtensions-\($0.uuidString)" } ?? "InstalledExtensions-Global"
        return FileManager.default.illuminateAppSupportDirectory().appendingPathComponent(dirName, isDirectory: true)
    }

    struct ExtensionRecord: Codable {
        let resourceURL: URL
        let isEnabled: Bool
        var source: ExtensionPackageSource?
        var installedVersion: String?
    }

    struct ExtensionLoadingError: Identifiable {
        let id = UUID()
        let extensionIdentifier: String
        let extensionName: String?
        let error: Error
        let timestamp = Date()
    }

    struct PermissionRequest: Identifiable {
        let id = UUID()
        let context: WKWebExtensionContext
        let permissions: Set<WKWebExtension.Permission>?
        let matchPatterns: Set<WKWebExtension.MatchPattern>?
        let urls: Set<URL>?
        let completion: (Bool) -> Void
        let createdAt = Date()
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

        loadExtensionStatesCache()
        loadPinnedExtensions()
        triggerLoad()
    }

    private func triggerLoad() {
        guard loadingTask == nil || loadingTask?.isCancelled == true else { return }
        loadingTask = Task { [weak self] in
            await self?.loadAllExtensions()
        }
    }

    private func loadAllExtensions() async {
        guard !isLoadingExtensions else { return }
        isLoadingExtensions = true
        loadingErrors = []

        defer {
            isLoadingExtensions = false
            loadingTask = nil
        }

        var newExtensions: [WKWebExtensionContext] = []
        var errors: [ExtensionLoadingError] = []

        if !isGuestSession {
            let records = loadPersistedRecords()
            let sortedKeys = records.keys.sorted()

            await withTaskGroup(of: (String, WKWebExtensionContext?, ExtensionLoadingError?).self) { group in
                for identifier in sortedKeys {
                    guard let record = records[identifier] else { continue }
                    group.addTask { [weak self] in
                        guard let self else { return (identifier, nil, nil) }
                        do {
                            let ctx = try await self.buildExtensionContext(
                                from: record.resourceURL,
                                identifier: identifier,
                                initiallyEnabled: record.isEnabled,
                                persist: false
                            )
                            return (identifier, ctx, nil)
                        } catch {
                            let err = ExtensionLoadingError(
                                extensionIdentifier: identifier,
                                extensionName: nil,
                                error: error
                            )
                            return (identifier, nil, err)
                        }
                    }
                }

                var resultMap: [String: WKWebExtensionContext] = [:]
                var errorMap: [String: ExtensionLoadingError] = [:]
                for await (id, ctx, err) in group {
                    if let ctx { resultMap[id] = ctx }
                    if let err { errorMap[id] = err }
                }
                for id in sortedKeys {
                    if let ctx = resultMap[id] { newExtensions.append(ctx) }
                    if let err = errorMap[id] { errors.append(err) }
                }
            }

            for (id, record) in records {
                if let source = record.source {
                    extensionSources[id] = source
                }
            }
        }

        let alreadyLoaded = Set(newExtensions.map { identifier(for: $0) })

        if let pluginsURL = Bundle.main.builtInPlugInsURL,
           FileManager.default.fileExists(atPath: pluginsURL.path),
           let pluginURLs = try? FileManager.default.contentsOfDirectory(
               at: pluginsURL, includingPropertiesForKeys: nil
           ) {
            let appexURLs = pluginURLs.filter { $0.pathExtension == "appex" }

            await withTaskGroup(of: (String, WKWebExtensionContext?, ExtensionLoadingError?).self) { group in
                for url in appexURLs {
                    group.addTask { [weak self] in
                        guard let self else { return (url.lastPathComponent, nil, nil) }
                        do {
                            let ctx = try await self.buildBundledExtensionContext(from: url)
                            return (url.lastPathComponent, ctx, nil)
                        } catch {
                            let err = ExtensionLoadingError(
                                extensionIdentifier: url.lastPathComponent,
                                extensionName: nil,
                                error: error
                            )
                            return (url.lastPathComponent, nil, err)
                        }
                    }
                }

                for await (_, ctx, err) in group {
                    if let ctx {
                        let ctxID = identifier(for: ctx)
                        guard !alreadyLoaded.contains(ctxID) else {
                            // Persisted copy takes precedence; don't add the bundled duplicate.
                            continue
                        }
                        newExtensions.append(ctx)
                    }
                    if let err { errors.append(err) }
                }
            }
        }

        installedExtensions = newExtensions
        loadingErrors = errors

        for error in errors {
            AppLog.error("Failed to load extension '\(error.extensionIdentifier)': \(error.error.localizedDescription)")
        }
    }

    private func loadPersistedRecords() -> [String: ExtensionRecord] {
        guard let data = try? Data(contentsOf: persistenceURL),
              let records = try? JSONDecoder().decode([String: ExtensionRecord].self, from: data)
        else { return [:] }
        return records
    }

    private func saveInstalledExtensions() {
        guard !isGuestSession else { return }

        var records: [String: ExtensionRecord] = [:]
        for context in installedExtensions {
            let id = identifier(for: context)
            guard !bundledExtensionIdentifiers.contains(id) else { continue }
            if let url = extensionResourceURLs[context.webExtension] {
                records[id] = ExtensionRecord(
                    resourceURL: url,
                    isEnabled: isEnabled(context),
                    source: extensionSources[id],
                    installedVersion: context.webExtension.version
                )
            }
        }

        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: persistenceURL, options: .atomic)
        }

        persistExtensionStates()
    }

    private func persistExtensionStates() {
        guard !isGuestSession else { return }
        userDefaults.set(extensionStatesCache, forKey: statesKey)
    }

    private func loadExtensionStatesCache() {
        extensionStatesCache = (userDefaults.dictionary(forKey: statesKey) as? [String: Bool]) ?? [:]
    }

    private func loadPinnedExtensions() {
        pinnedExtensions = Set(userDefaults.stringArray(forKey: pinnedExtensionsKey) ?? [])
    }

    private func persistPinnedExtensions() {
        guard !isGuestSession else { return }
        userDefaults.set(Array(pinnedExtensions), forKey: pinnedExtensionsKey)
    }

    private func buildExtensionContext(
        from url: URL,
        identifier preferredIdentifier: String?,
        initiallyEnabled: Bool,
        persist: Bool
    ) async throws -> WKWebExtensionContext {

        let extensionRepresentation = try await WKWebExtension(resourceBaseURL: url)
        if !extensionRepresentation.errors.isEmpty {
            let details = extensionRepresentation.errors.map(\.localizedDescription).joined(separator: "; ")
            AppLog.warning("Extension at '\(url.lastPathComponent)' reported parse issues: \(details)")
        }

        let context = WKWebExtensionContext(for: extensionRepresentation)
        let newID: String = preferredIdentifier
            ?? extensionRepresentation.displayName?
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            ?? context.uniqueIdentifier
        context.uniqueIdentifier = newID

        grantRequiredPermissions(for: context)
        prepareRuntimeStorageDirectory(for: newID, extensionName: extensionRepresentation.displayName)

        extensionResourceURLs[extensionRepresentation] = url
        if extensionStatesCache[newID] == nil {
            extensionStatesCache[newID] = initiallyEnabled
        }

        if isEnabled(context) {
            do {
                try controller.load(context)
            } catch {
                AppLog.error("Failed to load extension context '\(newID)': \(error.localizedDescription)")
                throw error
            }
        }

        if persist && !isGuestSession {
            var states = (userDefaults.dictionary(forKey: statesKey) as? [String: Bool]) ?? [:]
            states[newID] = initiallyEnabled
            userDefaults.set(states, forKey: statesKey)
        }

        return context
    }

    private func buildBundledExtensionContext(from url: URL) async throws -> WKWebExtensionContext {
        guard let bundle = Bundle(url: url) else {
            throw ExtensionError.invalidBundle(url)
        }
        let extensionRepresentation = try await WKWebExtension(appExtensionBundle: bundle)
        let context = WKWebExtensionContext(for: extensionRepresentation)
        let id = context.uniqueIdentifier

        bundledExtensionIdentifiers.insert(id)

        grantRequiredPermissions(for: context)
        prepareRuntimeStorageDirectory(for: id, extensionName: extensionRepresentation.displayName)

        if isEnabled(context) {
            try? controller.load(context)
        }

        return context
    }

    func identifier(for context: WKWebExtensionContext) -> String {
        context.uniqueIdentifier
    }

    func isBundled(_ context: WKWebExtensionContext) -> Bool {
        bundledExtensionIdentifiers.contains(identifier(for: context))
    }

    func isEnabled(_ context: WKWebExtensionContext) -> Bool {
        extensionStatesCache[identifier(for: context)] ?? true
    }

    func setEnabled(_ context: WKWebExtensionContext, enabled: Bool) {
        let id = identifier(for: context)

        extensionStatesCache[id] = enabled
        persistExtensionStates()

        if enabled {
            do {
                try controller.load(context)
            } catch {
                // Ignore "Extension context is already loaded" error - it's already in the desired state
                if error.localizedDescription.contains("already loaded") {
                    AppLog.debug("Extension context '\(id)' is already loaded")
                } else {
                    AppLog.error("Failed to load extension context '\(id)': \(error.localizedDescription)")
                }
            }
        } else {
            try? controller.unload(context)
        }

        saveInstalledExtensions()
        enabledStateVersion += 1
    }

    func isPinned(_ context: WKWebExtensionContext) -> Bool {
        pinnedExtensions.contains(identifier(for: context))
    }

    func setPinned(_ context: WKWebExtensionContext, pinned: Bool) {
        let id = identifier(for: context)
        if pinned {
            pinnedExtensions.insert(id)
        } else {
            pinnedExtensions.remove(id)
        }
        persistPinnedExtensions()
        objectWillChange.send()
    }

    func matchesGalleryItem(_ item: ExtensionGalleryItem, context: WKWebExtensionContext) -> Bool {
        if identifier(for: context) == item.id { return true }
        let names = [context.webExtension.displayName, context.webExtension.displayShortName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return names.contains { $0.caseInsensitiveCompare(item.name) == .orderedSame }
    }

    func installExtension(
        from url: URL,
        preferredIdentifier: String? = nil,
        initiallyEnabled: Bool = true,
        persist: Bool = true,
        source: ExtensionPackageSource? = nil
    ) async throws -> WKWebExtensionContext {
        let shouldPersist = persist && !isGuestSession
        let stagingID = preferredIdentifier ?? UUID().uuidString
        let packageURL = shouldPersist ? try persistPackage(from: url, identifier: stagingID) : url
        if let existing = installedExtensions.first(where: { identifier(for: $0) == stagingID }) {
            try? controller.unload(existing)
            installedExtensions = installedExtensions.filter { identifier(for: $0) != stagingID }
        }

        let context = try await buildExtensionContext(
            from: packageURL,
            identifier: stagingID,
            initiallyEnabled: initiallyEnabled,
            persist: shouldPersist
        )

        if let source {
            extensionSources[stagingID] = source
        }

        installedExtensions = installedExtensions + [context]

        if shouldPersist {
            saveInstalledExtensions()
        }

        // The extension is already loaded by buildExtensionContext if initiallyEnabled is true,
        // so we don't need to call setEnabled again. Just increment the version to trigger UI updates.
        if initiallyEnabled {
            enabledStateVersion += 1
            objectWillChange.send()
        }

        return context
    }


    func uninstallExtension(_ context: WKWebExtensionContext) {
        let id = identifier(for: context)
        try? controller.unload(context)

        extensionStatesCache.removeValue(forKey: id)
        extensionSources.removeValue(forKey: id)
        pinnedExtensions.remove(id)

        var states = (userDefaults.dictionary(forKey: statesKey) as? [String: Bool]) ?? [:]
        states.removeValue(forKey: id)
        userDefaults.set(states, forKey: statesKey)

        let canonicalURL = extensionsDirectory.appendingPathComponent(id, isDirectory: true)
        var removedPaths = Set<String>()

        if FileManager.default.fileExists(atPath: canonicalURL.path) {
            try? FileManager.default.removeItem(at: canonicalURL)
            removedPaths.insert(canonicalURL.path)
        }

        if let resourceURL = extensionResourceURLs[context.webExtension],
           !removedPaths.contains(resourceURL.path) {
            try? FileManager.default.removeItem(at: resourceURL)
        }
        extensionResourceURLs.removeValue(forKey: context.webExtension)
        extensionContextCache.removeAll(where: { $0 === context })
        removeRuntimeStorageDirectory(for: id, extensionName: context.webExtension.displayName)

        installedExtensions = installedExtensions.filter { $0 !== context }
        saveInstalledExtensions()
        enabledStateVersion += 1
        objectWillChange.send()
    }

    func scheduleAutoUpdates(initialDelay: TimeInterval = 10) {
        guard !isGuestSession else { return }
        autoUpdateTask?.cancel()
        autoUpdateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.checkAndUpdateExtensions()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.autoUpdateInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.checkAndUpdateExtensions()
            }
        }
    }

    func checkAndUpdateExtensions() async {
        guard !isGuestSession, !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        let snapshot = installedExtensions
        var updatedCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for context in snapshot {
                let id = identifier(for: context)
                guard let source = extensionSources[id] else { continue }
                let currentVersion = context.webExtension.version ?? ""

                group.addTask { [weak self] in
                    guard let self else { return false }
                    do {
                        let latestVersion = try await ExtensionPackageDownloader.latestReleaseVersion(for: source)
                        guard Self.isNewer(latestVersion, than: currentVersion) else { return false }

                        AppLog.info("Updating extension '\(id)': \(currentVersion) → \(latestVersion)")
                        let packageURL = try await ExtensionPackageDownloader.downloadUnpackedPackage(from: source)
                        _ = try await self.installExtension(
                            from: packageURL,
                            preferredIdentifier: id,
                            initiallyEnabled: self.isEnabled(context),
                            persist: true,
                            source: source
                        )
                        AppLog.info("Extension '\(id)' updated successfully.")
                        return true
                    } catch {
                        AppLog.error("Auto-update check failed for '\(id)': \(error.localizedDescription)")
                        return false
                    }
                }
            }

            for await didUpdate in group {
                if didUpdate { updatedCount += 1 }
            }
        }

        if updatedCount > 0 {
            AppLog.info("Auto-update: \(updatedCount) extension(s) updated.")
        }

        pendingUpdateCount = 0
    }

    nonisolated private static func isNewer(_ candidate: String, than installed: String) -> Bool {
        guard !candidate.isEmpty, !installed.isEmpty else { return false }
        let lhs = candidate.split(separator: ".").compactMap { Int($0) }
        let rhs = installed.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(lhs.count, rhs.count)
        for i in 0..<maxLen {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    func prepareForRemoval() {
        loadingTask?.cancel()
        loadingTask = nil
        autoUpdateTask?.cancel()
        autoUpdateTask = nil
        permissionRequestTimeoutTask?.cancel()
        permissionRequestTimeoutTask = nil

        for (_, pending) in pendingWindows {
            pending.timeoutTask.cancel()
            pending.completion(nil, ExtensionError.managerDeallocated)
        }
        pendingWindows.removeAll()


        extensionContextCache.removeAll()
        tabManagers.removeAll()

        AppLog.info("ExtensionManager torn down for profile: \(profileID?.uuidString ?? "global")")
    }

    var activeTabManager: TabManager? {
        tabManagers.first { $0.isFocused } ?? tabManagers.first
    }

    func registerTabManager(_ tabManager: TabManager) {
        tabManagers.insert(tabManager)
        let pending = pendingWindows
        for (_, entry) in pending {
            entry.timeoutTask.cancel()
            entry.completion(tabManager, nil)
            pendingWindows.removeValue(forKey: entry.id)
        }
    }

    func unregisterTabManager(_ tabManager: TabManager) {
        tabManagers.remove(tabManager)
    }

    func unregisterTabManager(withIdentifier id: ObjectIdentifier) {
        if let manager = tabManagers.first(where: { ObjectIdentifier($0) == id }) {
            tabManagers.remove(manager)
        }
    }

    func getExtensionContext(for url: URL) -> WKWebExtensionContext? {
        if let cached = extensionContextCache.value(for: url) { return cached }

        guard url.scheme == "webkit-extension" else { return nil }

        let urlString = url.absoluteString
        guard let prefixRange = urlString.range(of: "webkit-extension://", options: .caseInsensitive) else {
            return nil
        }
        let afterPrefix = urlString[prefixRange.upperBound...]
        guard let slashIndex = afterPrefix.firstIndex(of: "/") else { return nil }
        let extensionID = String(afterPrefix[..<slashIndex])

        guard let context = installedExtensions.first(where: { $0.uniqueIdentifier == extensionID }) else {
            return nil
        }
        extensionContextCache.insert(context, for: url)
        return context
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
        if isDirectory {
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

    private func prepareRuntimeStorageDirectory(for uniqueIdentifier: String, extensionName: String? = nil) {
        guard !isGuestSession,
              let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        else { return }
        var dir = library
            .appendingPathComponent("WebKit", isDirectory: true)
            .appendingPathComponent("WebExtensions", isDirectory: true)
        if let profileID { dir = dir.appendingPathComponent(profileID.uuidString, isDirectory: true) }
        dir = dir.appendingPathComponent(uniqueIdentifier, isDirectory: true)

        // If extension name is provided, create the extension-specific subdirectory
        if let extensionName = extensionName {
            dir = dir.appendingPathComponent(extensionName, isDirectory: true)
        }

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            guard FileManager.default.fileExists(atPath: dir.path) else {
                AppLog.error("Runtime storage directory was not created for extension \(uniqueIdentifier)")
                return
            }
        } catch {
            AppLog.error("Failed to create runtime storage directory for extension \(uniqueIdentifier): \(error)")
        }
    }

    private func removeRuntimeStorageDirectory(for uniqueIdentifier: String, extensionName: String? = nil) {
        guard !isGuestSession,
              let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        else { return }
        var dir = library
            .appendingPathComponent("WebKit", isDirectory: true)
            .appendingPathComponent("WebExtensions", isDirectory: true)
        if let profileID { dir = dir.appendingPathComponent(profileID.uuidString, isDirectory: true) }
        dir = dir.appendingPathComponent(uniqueIdentifier, isDirectory: true)

        // If extension name is provided, remove the extension-specific subdirectory
        if let extensionName = extensionName {
            dir = dir.appendingPathComponent(extensionName, isDirectory: true)
        }

        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            AppLog.warning("Could not remove runtime storage for '\(uniqueIdentifier)': \(error.localizedDescription)")
        }
    }

    enum ExtensionError: LocalizedError {
        case invalidBundle(URL)
        case managerDeallocated

        var errorDescription: String? {
            switch self {
            case .invalidBundle(let url):
                return "Could not load bundle at \(url.lastPathComponent)"
            case .managerDeallocated:
                return "The extension manager was torn down before this operation could complete"
            }
        }
    }

    deinit {
        AppLog.info("ExtensionManager deallocated for profile: \(profileID?.uuidString ?? "global")")
    }
}

extension ExtensionManager: WKWebExtensionControllerDelegate {

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openWindowsFor context: WKWebExtensionContext
    ) -> [any WKWebExtensionWindow] {
        var windows = Array(tabManagers)
        if let active = activeTabManager, let idx = windows.firstIndex(where: { $0 === active }) {
            windows.move(fromOffsets: IndexSet(integer: idx), toOffset: 0)
        }
        return windows
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openNewTabUsing configuration: WKWebExtension.TabConfiguration,
        for context: WKWebExtensionContext,
        completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void
    ) {
        guard let tabManager = (configuration.window as? TabManager) ?? activeTabManager else {
            completionHandler(nil, NSError(
                domain: "ExtensionManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No active window found"]
            ))
            return
        }

        if let url = configuration.url {
            extensionContextCache.insert(context, for: url)
        }

        let tab = tabManager.createTab(url: configuration.url, inBackground: !configuration.shouldBeActive)

        if let parentTab = configuration.parentTab as? Tab {
            tab.parentTab = parentTab
        }

        let requestedIndex = configuration.index
        if requestedIndex >= 0,
           let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == tab.id }),
           requestedIndex != currentIndex,
           requestedIndex < tabManager.tabs.count {
            tabManager.moveTab(fromOffsets: IndexSet(integer: currentIndex), toOffset: requestedIndex)
        }

        completionHandler(tab, nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
        for context: WKWebExtensionContext,
        completionHandler: @escaping (WKWebExtensionWindow?, (any Error)?) -> Void
    ) {
        let pendingID = UUID()

        let timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 s
            guard !Task.isCancelled, let self else { return }
            if let entry = self.pendingWindows.removeValue(forKey: pendingID) {
                AppLog.warning("Window creation timed out for extension: \(context.webExtension.displayName ?? "unknown")")
                entry.completion(nil, NSError(
                    domain: "ExtensionManager", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Window creation timed out"]
                ))
            }
        }

        let pending = PendingWindow(id: pendingID, completion: completionHandler, timeoutTask: timeoutTask)
        pendingWindows[pendingID] = pending

        let firstURL = configuration.tabs.first?.url
        NotificationCenter.default.post(name: NSNotification.Name("app.openNewWindow"), object: firstURL)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        focusedWindowFor context: WKWebExtensionContext
    ) -> WKWebExtensionWindow? {
        activeTabManager
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openOptionsPageFor context: WKWebExtensionContext,
        completionHandler: @escaping ((any Error)?) -> Void
    ) {
        guard let url = context.optionsPageURL else {
            completionHandler(NSError(
                domain: "ExtensionManager", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Options page not defined in manifest"]
            ))
            return
        }
        extensionContextCache.insert(context, for: url)
        NotificationCenter.default.post(name: .openURL, object: url)
        completionHandler(nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissions permissions: Set<WKWebExtension.Permission>,
        in tab: (any WKWebExtensionTab)?,
        for context: WKWebExtensionContext,
        completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void
    ) {
        let request = PermissionRequest(
            context: context,
            permissions: permissions,
            matchPatterns: nil,
            urls: nil,
            completion: { granted in completionHandler(granted ? permissions : [], nil) }
        )
        presentPermissionRequest(request)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
        in tab: (any WKWebExtensionTab)?,
        for context: WKWebExtensionContext,
        completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void
    ) {
        let request = PermissionRequest(
            context: context,
            permissions: nil,
            matchPatterns: matchPatterns,
            urls: nil,
            completion: { granted in completionHandler(granted ? matchPatterns : [], nil) }
        )
        presentPermissionRequest(request)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissionToAccess urls: Set<URL>,
        in tab: (any WKWebExtensionTab)?,
        for context: WKWebExtensionContext,
        completionHandler: @escaping (Set<URL>, Date?) -> Void
    ) {
        let request = PermissionRequest(
            context: context,
            permissions: nil,
            matchPatterns: nil,
            urls: urls,
            completion: { granted in completionHandler(granted ? urls : [], nil) }
        )
        presentPermissionRequest(request)
    }

    private func presentPermissionRequest(_ request: PermissionRequest) {
        permissionRequestTimeoutTask?.cancel()
        activePermissionRequest = request

        permissionRequestTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 min
            guard !Task.isCancelled, let self else { return }
            guard self.activePermissionRequest?.id == request.id else { return }
            AppLog.warning("Permission request timed out for extension: \(request.context.webExtension.displayName ?? "unknown")")
            request.completion(false)
            self.activePermissionRequest = nil
        }
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        didUpdate action: WKWebExtension.Action,
        forExtensionContext context: WKWebExtensionContext
    ) {
        actionChanges.send((context, action.associatedTab))
    }
}
