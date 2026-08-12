//
//  TabGroupManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Combine
import Foundation
import OSLog
import SwiftUI

@MainActor
final class TabGroupManager: ObservableObject {
    private enum Defaults {
        static let maxClosedGroups = 10
        static let groupSaveDebounceNs: UInt64 = 500_000_000
    }

    @Published private(set) var groups: [TabGroup] = []
    @Published private(set) var closedGroups: [ClosedGroupSnapshot] = []

    private let isPersistenceEnabled: Bool
    private let groupsURL: URL
    private let logger = Logger(subsystem: "com.illuminate", category: "TabGroupManager")
    private var pendingSaveTask: Task<Void, Never>?
    private var saveVersion: UInt64 = 0
    private var tabGroupIndex: [UUID: UUID] = [:]
    private var groupIndex: [UUID: TabGroup] = [:]

    /// Forwards each TabGroup's own objectWillChange so mutations to an
    /// individual group (rename, collapse, add/remove tab, etc.) are
    /// reflected through `$groups` — not just structural array changes.
    /// This is what makes SwiftUI views observing `$groups` (like
    /// TabBarView) update without needing an unrelated action to happen.
    private var groupSubscriptions: [UUID: AnyCancellable] = [:]

    init(profileID: UUID?, isPersistenceEnabled: Bool = true) {
        self.isPersistenceEnabled = isPersistenceEnabled

        let base: URL = profileID.map {
            FileManager.default.illuminateProfileDirectory(profileID: $0)
        } ?? FileManager.default.illuminateAppSupportDirectory()
        self.groupsURL = base.appendingPathComponent("tab_groups.json")

        if isPersistenceEnabled {
            restoreGroups()
        }
    }

    func group(for tabID: UUID) -> TabGroup? {
        guard let groupID = tabGroupIndex[tabID] else { return nil }
        return groupIndex[groupID]
    }

    func group(byID id: UUID) -> TabGroup? {
        groupIndex[id]
    }

    /// Position of a group within the ordered `groups` array.
    /// (Previously named `groupIndex(of:)`, which collided in name with the
    /// `groupIndex` dictionary property below — renamed for clarity.)
    func position(ofGroup groupID: UUID) -> Int? {
        groups.firstIndex(where: { $0.id == groupID })
    }

    func orderedTabIDs(allTabs: [Tab]) -> [UUID] {
        var result: [UUID] = []
        var processedTabIDs = Set<UUID>()

        for tab in allTabs {
            guard !processedTabIDs.contains(tab.id) else { continue }

            if let group = group(for: tab.id) {
                for gTabID in group.tabIDs {
                    if !processedTabIDs.contains(gTabID) {
                        result.append(gTabID)
                        processedTabIDs.insert(gTabID)
                    }
                }
            } else {
                result.append(tab.id)
                processedTabIDs.insert(tab.id)
            }
        }
        return result
    }

    @discardableResult
    func createGroup(
        name: String = "",
        color: TabGroupColor = .blue,
        tabIDs: [UUID] = []
    ) -> TabGroup {
        for tabID in tabIDs {
            removeTabFromGroup(tabID)
        }

        let group = TabGroup(
            name: name,
            groupColor: color,
            tabIDs: tabIDs
        )
        group.isNew = true

        addToStorage(group)

        for tabID in tabIDs {
            tabGroupIndex[tabID] = group.id
        }

        scheduleSave()
        return group
    }

    func deleteGroup(_ groupID: UUID) {
        guard let group = groupIndex[groupID] else { return }

        for tabID in group.tabIDs {
            tabGroupIndex.removeValue(forKey: tabID)
        }

        removeFromStorage(groupID)
        scheduleSave()
    }

    func renameGroup(_ groupID: UUID, to name: String) {
        guard let group = groupIndex[groupID] else { return }
        group.name = name
        scheduleSave()
    }

    func changeGroupColor(_ groupID: UUID, to color: TabGroupColor) {
        guard let group = groupIndex[groupID] else { return }
        group.groupColor = color
        scheduleSave()
    }

    func addTabToGroup(_ tabID: UUID, groupID: UUID) {
        removeTabFromGroup(tabID)

        guard let group = groupIndex[groupID] else { return }
        group.addTab(tabID)
        tabGroupIndex[tabID] = groupID

        scheduleSave()
    }

    func removeTabFromGroup(_ tabID: UUID) {
        guard let groupID = tabGroupIndex[tabID],
              let group = groupIndex[groupID] else { return }
        group.removeTab(tabID)
        tabGroupIndex.removeValue(forKey: tabID)

        if group.isEmpty {
            deleteGroup(groupID)
        }

        scheduleSave()
    }

    func moveTabToGroup(_ tabID: UUID, targetGroupID: UUID, at index: Int? = nil) {
        removeTabFromGroup(tabID)

        guard let group = groupIndex[targetGroupID] else { return }
        if let index {
            group.insertTab(tabID, at: index)
        } else {
            group.addTab(tabID)
        }
        tabGroupIndex[tabID] = targetGroupID

        scheduleSave()
    }

    func toggleCollapse(_ groupID: UUID) {
        guard let group = groupIndex[groupID] else { return }
        group.isCollapsed.toggle()
        scheduleSave()
    }

    func collapseGroup(_ groupID: UUID) {
        guard let group = groupIndex[groupID] else { return }
        group.isCollapsed = true
        scheduleSave()
    }

    func expandGroup(_ groupID: UUID) {
        guard let group = groupIndex[groupID] else { return }
        group.isCollapsed = false
        scheduleSave()
    }

    func closeGroup(_ groupID: UUID, tabs: [Tab]) {
        guard let group = groupIndex[groupID] else { return }

        let tabPayloads = group.tabIDs.compactMap { tabID -> TabTransferPayload? in
            tabs.first(where: { $0.id == tabID })?.toTransferPayload()
        }

        let snapshot = ClosedGroupSnapshot(
            groupPayload: group.toPayload(),
            tabPayloads: tabPayloads,
            closedDate: Date()
        )

        closedGroups.append(snapshot)
        if closedGroups.count > Defaults.maxClosedGroups {
            closedGroups.removeFirst()
        }

        deleteGroup(groupID)
    }

    /// Restores a previously closed group's metadata (name, color, etc.).
    /// Note: this does not repopulate `tabIDs` — the caller is expected to
    /// recreate the actual `Tab`s from `snapshot.tabPayloads` and re-add
    /// them via `addTabToGroup`/`moveTabToGroup` once they exist.
    func restoreGroup(at index: Int) -> ClosedGroupSnapshot? {
        guard closedGroups.indices.contains(index) else { return nil }
        let snapshot = closedGroups.remove(at: index)

        let colorValue = TabGroupColor(rawValue: snapshot.groupPayload.color) ?? .blue
        let group = TabGroup(
            id: snapshot.groupPayload.id,
            name: snapshot.groupPayload.name,
            groupColor: colorValue,
            isCollapsed: snapshot.groupPayload.isCollapsed,
            tabIDs: [],
            createdDate: snapshot.groupPayload.createdDate
        )

        addToStorage(group)
        scheduleSave()

        return snapshot
    }

    func restoreLatestGroup() -> ClosedGroupSnapshot? {
        guard !closedGroups.isEmpty else { return nil }
        return restoreGroup(at: closedGroups.count - 1)
    }

    func handleTabClosed(_ tabID: UUID) {
        removeTabFromGroup(tabID)
    }

    /// Call when tabs are reordered to keep group membership/ordering consistent.
    func handleTabsReordered(_ tabIDs: [UUID]) {
        autoJoinSandwichedTabs(in: tabIDs)
        syncGroupOrder(to: tabIDs)
        scheduleSave()
    }

    /// If a tab ends up sandwiched between two tabs that belong to the same
    /// group, fold it into that group automatically.
    private func autoJoinSandwichedTabs(in tabIDs: [UUID]) {
        guard tabIDs.count >= 3 else { return }

        for i in 1..<(tabIDs.count - 1) {
            let prevTabID = tabIDs[i - 1]
            let nextTabID = tabIDs[i + 1]
            let currentTabID = tabIDs[i]

            guard let prevGroupID = tabGroupIndex[prevTabID],
                  let nextGroupID = tabGroupIndex[nextTabID],
                  prevGroupID == nextGroupID,
                  tabGroupIndex[currentTabID] != prevGroupID,
                  let targetGroup = groupIndex[prevGroupID]
            else { continue }

            // Leave whatever group the tab is currently in, if any.
            if let oldGroupID = tabGroupIndex[currentTabID],
               let oldGroup = groupIndex[oldGroupID] {
                oldGroup.removeTab(currentTabID)
                if oldGroup.isEmpty { deleteGroup(oldGroupID) }
            }

            targetGroup.addTab(currentTabID)
            tabGroupIndex[currentTabID] = prevGroupID
        }
    }

    /// Re-orders each group's `tabIDs` to match the new overall tab order.
    private func syncGroupOrder(to tabIDs: [UUID]) {
        for group in groups {
            let currentIDs = group.tabIDs
            let reordered = tabIDs.filter { currentIDs.contains($0) }
            guard reordered != currentIDs else { continue }

            for id in currentIDs {
                group.removeTab(id)
            }
            for id in reordered {
                group.addTab(id)
            }
        }
    }

    // MARK: - Storage helpers

    private func addToStorage(_ group: TabGroup) {
        groups.append(group)
        groupIndex[group.id] = group
        observe(group)
    }

    private func removeFromStorage(_ groupID: UUID) {
        groups.removeAll { $0.id == groupID }
        groupIndex.removeValue(forKey: groupID)
        stopObserving(groupID)
    }

    private func observe(_ group: TabGroup) {
        groupSubscriptions[group.id] = group.objectWillChange
            .sink { [weak self] _ in
                self?.republishGroups()
            }
    }

    private func stopObserving(_ groupID: UUID) {
        groupSubscriptions[groupID]?.cancel()
        groupSubscriptions.removeValue(forKey: groupID)
    }

    /// Re-publishes `groups` so any `TabGroup` mutation (collapse, rename,
    /// color change, tab add/remove) is visible to `$groups` subscribers,
    /// not just structural array changes (add/remove group).
    private func republishGroups() {
        groups = groups
    }

    // MARK: - Persistence

    private func scheduleSave() {
        guard isPersistenceEnabled else { return }

        pendingSaveTask?.cancel()
        saveVersion &+= 1
        let version = saveVersion

        pendingSaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Defaults.groupSaveDebounceNs)
            guard !Task.isCancelled else { return }
            guard version == self.saveVersion else { return }

            let payloads = self.groups.map { $0.toPayload() }
            let url = self.groupsURL
            let log = self.logger

            Task.detached(priority: .background) {
                do {
                    let directory = url.deletingLastPathComponent()
                    try FileManager.default.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )
                    let data = try JSONEncoder().encode(payloads)
                    try data.write(to: url, options: .atomic)
                } catch {
                    log.error("[TabGroupManager] Group save failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func restoreGroups() {
        do {
            let data = try Data(contentsOf: groupsURL)
            let payloads = try JSONDecoder().decode([TabGroupPayload].self, from: data)

            for payload in payloads {
                let color = TabGroupColor(rawValue: payload.color) ?? .blue
                let group = TabGroup(
                    id: payload.id,
                    name: payload.name,
                    groupColor: color,
                    isCollapsed: payload.isCollapsed,
                    tabIDs: payload.tabIDs,
                    createdDate: payload.createdDate
                )
                addToStorage(group)
                for tabID in payload.tabIDs {
                    tabGroupIndex[tabID] = group.id
                }
            }
        } catch {
            let nsError = error as NSError
            let isMissing = nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError
            if !isMissing {
                logger.error("[TabGroupManager] Group restore failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}