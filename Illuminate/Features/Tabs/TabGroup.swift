//
//  TabGroup.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import Observation
import SwiftUI

enum TabGroupColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, red, yellow, green, purple, pink, orange, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:   return Color(hue: 0.58, saturation: 0.65, brightness: 0.92)
        case .red:    return Color(hue: 0.0, saturation: 0.62, brightness: 0.90)
        case .yellow: return Color(hue: 0.13, saturation: 0.60, brightness: 0.95)
        case .green:  return Color(hue: 0.38, saturation: 0.55, brightness: 0.82)
        case .purple: return Color(hue: 0.77, saturation: 0.50, brightness: 0.85)
        case .pink:   return Color(hue: 0.92, saturation: 0.45, brightness: 0.92)
        case .orange: return Color(hue: 0.07, saturation: 0.70, brightness: 0.95)
        case .gray:   return Color(hue: 0.0, saturation: 0.0, brightness: 0.60)
        }
    }

    var displayName: String { rawValue.capitalized }
}


@MainActor
@Observable
final class TabGroup: Identifiable {
    let id: UUID
    let createdDate: Date

    var name: String
    var groupColor: TabGroupColor
    var isCollapsed: Bool
    var isNew: Bool = false
    private(set) var tabIDs: [UUID] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        groupColor: TabGroupColor = .blue,
        isCollapsed: Bool = false,
        tabIDs: [UUID] = [],
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.groupColor = groupColor
        self.isCollapsed = isCollapsed
        self.tabIDs = tabIDs
        self.createdDate = createdDate
    }

    var tabCount: Int { tabIDs.count }
    var isEmpty: Bool { tabIDs.isEmpty }

    func contains(_ tabID: UUID) -> Bool {
        tabIDs.contains(tabID)
    }

    func addTab(_ tabID: UUID) {
        guard !tabIDs.contains(tabID) else { return }
        tabIDs.append(tabID)
    }

    func addTabs(_ ids: [UUID]) {
        for id in ids {
            guard !tabIDs.contains(id) else { continue }
            tabIDs.append(id)
        }
    }

    func removeTab(_ tabID: UUID) {
        tabIDs.removeAll { $0 == tabID }
    }

    func insertTab(_ tabID: UUID, at index: Int) {
        guard !tabIDs.contains(tabID) else { return }
        let clamped = min(max(index, 0), tabIDs.count)
        tabIDs.insert(tabID, at: clamped)
    }

    func moveTab(fromIndex: Int, toIndex: Int) {
        guard tabIDs.indices.contains(fromIndex) else { return }
        let id = tabIDs.remove(at: fromIndex)
        let destination = min(max(toIndex, 0), tabIDs.count)
        tabIDs.insert(id, at: destination)
    }

    func index(of tabID: UUID) -> Int? {
        tabIDs.firstIndex(of: tabID)
    }

    func toPayload() -> TabGroupPayload {
        TabGroupPayload(
            id: id,
            name: name,
            color: groupColor.rawValue,
            isCollapsed: isCollapsed,
            tabIDs: tabIDs,
            createdDate: createdDate
        )
    }
}

struct TabGroupPayload: Codable, Sendable {
    var id: UUID
    var name: String
    var color: String
    var isCollapsed: Bool
    var tabIDs: [UUID]
    var createdDate: Date
}

struct ClosedGroupSnapshot {
    let groupPayload: TabGroupPayload
    let tabPayloads: [TabTransferPayload]
    let closedDate: Date
}
