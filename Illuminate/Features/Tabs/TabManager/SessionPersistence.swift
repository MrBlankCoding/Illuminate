//
//  TabManagerSessionPersistence.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import Foundation
import SwiftUI
import Synchronization
import WebKit

actor SessionWriter {
    var latestVersion: UInt64 = 0

    func write(data: Data, version: UInt64, to url: URL) async {
        guard version >= latestVersion else { return }
        latestVersion = version
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.error("[TabManager] Session write failed", error: error)
        }
    }
}

enum StateFilePrefetcher {
    private static let cache = Mutex<[URL: Data]>([:])

    static func prefetch(_ urls: [URL]) {
        Task.detached(priority: .userInitiated) {
            for url in urls {
                guard let data = try? Data(contentsOf: url) else { continue }
                await cache.withLock { $0[url] = data }
            }
        }
    }

    static func consume(_ url: URL) -> Data? {
        cache.withLock { $0.removeValue(forKey: url) }
    }
}

@MainActor
extension TabManager {
    static func makeSessionURL(profileID: UUID?) -> URL {
        let base: URL = profileID.map {
            FileManager.default.illuminateProfileDirectory(profileID: $0)
        } ?? FileManager.default.illuminateAppSupportDirectory()
        return base.appendingPathComponent("session.json")
    }
    func restoreSession() {
        let url = sessionURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLog.info("[TabManager] No session file found — starting fresh.")
            startFreshSession()
            return
        }

        do {
            let data: Data
            if let prefetched = StateFilePrefetcher.consume(url) {
                data = prefetched
            } else {
                data = try Data(contentsOf: url)
            }
            let state = try JSONDecoder().decode(SessionState.self, from: data)
            applySessionState(state)
        } catch let error as DecodingError {
            AppLog.error("[TabManager] Session file is corrupt — backing up and starting fresh", error: error)
            backupCorruptSession(at: url)
            startFreshSession()
        } catch {
            let nsError = error as NSError
            let isMissingFile = nsError.domain == NSCocoaErrorDomain
                && nsError.code == NSFileReadNoSuchFileError
            if isMissingFile {
                AppLog.info("[TabManager] No session file found — starting fresh.")
            } else {
                AppLog.error("[TabManager] Session restore failed", error: error)
            }
            startFreshSession()
        }
    }

    func applySessionState(_ state: SessionState) {
        activeTabID = state.activeTabID
        if let ids = state.tabIDs {
            tabs = ids.map {
                let isActive = $0 == activeTabID
                let tab = Tab(id: $0, assetsBaseURL: tabAssetsBaseURL, loadsMetadataSynchronously: isActive)
                tab.tabManager = self
                return tab
            }
            } else if let payloads = state.tabs {
                tabs = payloads.map {
                    let tab = makeTab(from: $0)
                    tab.tabManager = self
                    return tab
                }
            }
        rebuildTabIndex()
        updateProtectedFaviconURLs()
    }

    func startFreshSession() {
        let tab = Tab(assetsBaseURL: tabAssetsBaseURL)
        tabs = [tab]
        pristineBlankTabID = tab.id
        rebuildTabIndex()
    }

    func backupCorruptSession(at url: URL) {
        let backupURL = url
            .deletingPathExtension()
            .appendingPathExtension("json.corrupt.\(Int(Date().timeIntervalSince1970))")
        do {
            try FileManager.default.copyItem(at: url, to: backupURL)
            AppLog.info("[TabManager] Backed up corrupt session to \(backupURL.lastPathComponent)")
            try FileManager.default.removeItem(at: url)
        } catch {
            AppLog.error("[TabManager] Could not back up corrupt session file", error: error)
        }
    }

    func hydrateRestoredTabs() {
        if let activeID = activeTabID, let activeTab = tabIndex[activeID] {
            hydrateVisualState(for: activeTab)
        }

        let otherTabs = tabs.filter { $0.id != activeTabID }
        guard !otherTabs.isEmpty else { return }
        beginInitialTabPreloadingSuppression(for: otherTabs)
        Task { @MainActor [weak self] in
            for tab in otherTabs {
                self?.hydrateVisualState(for: tab)
                await Task.yield()
            }
        }
    }

    func scheduleSave() {
        guard isPersistenceEnabled else { return }

        pendingSaveTask?.cancel()
        saveVersion &+= 1
        let version = saveVersion
        let now = Date()
        let debounceInterval: UInt64
        if let lastSwitch = lastSwitchTime, now.timeIntervalSince(lastSwitch) < 1.0 {
            debounceInterval = Defaults.rapidSwitchDebounceNs
        } else {
            debounceInterval = Defaults.saveDebounceNs
        }

        pendingSaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceInterval)
            guard !Task.isCancelled else { return }

            let state = SessionState(
                tabIDs: self.tabs.map { $0.id },
                activeTabID: self.activeTabID
            )
            let url     = self.sessionURL
            let encoded = try? JSONEncoder().encode(state)
            let writer  = self.sessionWriter

            Task.detached(priority: .background) {
                guard let data = encoded else { return }
                await writer.write(data: data, version: version, to: url)
            }
        }
    }
    func persistIfEnabled(_ value: some UserDefaultsStorable, forKey key: String) {
        guard isPersistenceEnabled else { return }
        userDefaults.set(value, forKey: scopedKey(key))
    }
    func scopedKey(_ key: String) -> String {
        Self.scopedKey(key, profileID: activeProfileID)
    }

    static func scopedKey(_ key: String, profileID: UUID?) -> String {
        guard let profileID else { return key }
        return "profile.\(profileID.uuidString).\(key)"
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) as? Bool ?? defaultValue
    }
}


protocol UserDefaultsStorable {}
extension String: UserDefaultsStorable {}
extension Bool:   UserDefaultsStorable {}
extension Int:    UserDefaultsStorable {}
extension Double: UserDefaultsStorable {}
