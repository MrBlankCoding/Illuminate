//
//  TabBarView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

private enum TabBarMetrics {
    static let minTabWidth: CGFloat = 48
    static let maxTabWidth: CGFloat = 220
    static let tabSpacing: CGFloat = 3
    static let scrollThreshold: CGFloat = 72
    static let newTabButtonSize: CGFloat = 28
    static let rowHeight: CGFloat = 42
    static let reorderAnimation: Animation = .spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.1)
}

private struct TabDragSession {
    var tabID: UUID
    var startIndex: Int
    var currentIndex: Int      // where it would land if the drag ended now
    var translation: CGFloat = 0
    var tabWidth: CGFloat
    var spacing: CGFloat = TabBarMetrics.tabSpacing

    var stride: CGFloat { tabWidth + spacing }
}

private enum TabBarElement: Identifiable, Equatable {
    case group(UUID, [UUID])
    case tab(UUID)

    var id: String {
        switch self {
        case .group(let id, _): return "group-\(id)"
        case .tab(let id): return "tab-\(id)"
        }
    }
}

struct TabBarView: View {
    @EnvironmentObject private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var dragSession: TabDragSession?
    @State private var isNewTabHovered = false
    @State private var groupChangeToken = UUID()
    @State private var previousActiveTabID: UUID?
    @Namespace private var activeTabNamespace

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    private var layoutElements: [TabBarElement] {
        var elements: [TabBarElement] = []
        var processedTabIDs = Set<UUID>()
        let groupsManager = tabManager.tabGroupManager
        let currentTabs = tabManager.tabs

        for tab in currentTabs {
            guard !processedTabIDs.contains(tab.id) else { continue }

            if let group = groupsManager.group(for: tab.id) {
                elements.append(.group(group.id, group.tabIDs))
                for gTabID in group.tabIDs {
                    processedTabIDs.insert(gTabID)
                }
            } else {
                elements.append(.tab(tab.id))
                processedTabIDs.insert(tab.id)
            }
        }
        return elements
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                tabStrip(availableWidth: geo.size.width)
                newTabButton
            }
        }
        .frame(height: TabBarMetrics.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser.tabbar")
        .accessibilityLabel("Tab strip, \(tabManager.tabs.count) \(tabManager.tabs.count == 1 ? "tab" : "tabs")")
        .onReceive(tabManager.tabGroupManager.$groups) { _ in
            groupChangeToken = UUID()
        }
    }

    @ViewBuilder
    private func tabStrip(availableWidth: CGFloat) -> some View {
        let count    = max(tabManager.tabs.count, 1)
        let newTabRoom = TabBarMetrics.newTabButtonSize + TabBarMetrics.tabSpacing
        let spacing  = TabBarMetrics.tabSpacing * CGFloat(count - 1)
        let usable   = availableWidth - newTabRoom
        let rawWidth = (usable - spacing) / CGFloat(count)
        let tabWidth = min(max(rawWidth, TabBarMetrics.minTabWidth), TabBarMetrics.maxTabWidth)

        if tabWidth <= TabBarMetrics.scrollThreshold {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    tabRow(tabWidth: TabBarMetrics.scrollThreshold)
                }
                .onChange(of: tabManager.activeTabID) { _, newID in
                    guard newID != previousActiveTabID else { return }
                    previousActiveTabID = newID
                    if let id = newID {
                        withAnimation(MacDesign.springAnimation) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        } else {
            tabRow(tabWidth: tabWidth)
        }
    }

    private func tabRow(tabWidth: CGFloat) -> some View {
        HStack(spacing: TabBarMetrics.tabSpacing) {
            ForEach(layoutElements) { element in
                switch element {
                case .group(let groupID, let tabIDs):
                    if let group = tabManager.tabGroupManager.group(byID: groupID) {
                        HStack(spacing: TabBarMetrics.tabSpacing) {
                            TabGroupHeaderView(
                                group: group,
                                onToggleCollapse: {
                                    withAnimation(MacDesign.springAnimation) {
                                        tabManager.tabGroupManager.toggleCollapse(groupID)
                                    }
                                },
                                onRename: { tabManager.tabGroupManager.renameGroup(groupID, to: $0) },
                                onChangeColor: { tabManager.tabGroupManager.changeGroupColor(groupID, to: $0) },
                                onCloseGroup: {
                                    let ids = group.tabIDs
                                    tabManager.tabGroupManager.closeGroup(groupID, tabs: tabManager.tabs)
                                    ids.forEach { tabManager.closeTab(id: $0) }
                                },
                                onDeleteGroup: { tabManager.tabGroupManager.deleteGroup(groupID) },
                                onUngroupTabs: {
                                    for id in group.tabIDs {
                                        tabManager.tabGroupManager.removeTabFromGroup(id)
                                    }
                                }
                            )
                            .padding(.trailing, 2)
                            .padding(.leading, 2)

                            if !group.isCollapsed {
                                ForEach(tabIDs, id: \.self) { tabID in
                                    renderTab(tabID: tabID, tabWidth: tabWidth)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(group.groupColor.color)
                                .frame(height: 2)
                                .padding(.horizontal, 4)
                        }
                    }

                case .tab(let tabID):
                    renderTab(tabID: tabID, tabWidth: tabWidth)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 2)
    }

    @ViewBuilder
    private func renderTab(tabID: UUID, tabWidth: CGFloat) -> some View {
        if let tab = tabManager.tab(forID: tabID),
           let index = tabManager.indexOfTab(withID: tabID) {
            let isDragging  = dragSession?.tabID == tab.id
            let dragOffsetX = offset(forTabAt: index, isDragging: isDragging)

            TabItemView(
                tab: tab,
                themeColor: tabManager.windowThemeColor,
                isActive: tab.id == tabManager.activeTabID,
                namespace: activeTabNamespace,
                onSelect: {
                    withAnimation(MacDesign.springAnimation) { tabManager.switchTo(tab.id) }
                },
                onClose: {
                    withAnimation(MacDesign.springAnimation) { tabManager.closeTab(id: tab.id) }
                },
                onDuplicate: {
                    if let url = tab.url { tabManager.createTab(url: url) }
                },
                onCloseOthers: {
                    let ids = tabManager.tabs.filter { $0.id != tab.id }.map { $0.id }
                    withAnimation(MacDesign.springAnimation) { ids.forEach { tabManager.closeTab(id: $0) } }
                },
                onCloseToRight: {
                    guard let idx = tabManager.indexOfTab(withID: tab.id) else { return }
                    let ids = tabManager.tabs[(idx + 1)...].map { $0.id }
                    withAnimation(MacDesign.springAnimation) { ids.forEach { tabManager.closeTab(id: $0) } }
                },
                onCopyLink: {
                    guard let s = tab.url?.absoluteString, !s.isEmpty else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(s, forType: .string)
                },
                onToggleMute: { tab.toggleMute() }
            )
            .frame(width: tabWidth)
            .zIndex(isDragging ? 1 : 0)
            .offset(x: dragOffsetX)
            .opacity(isDragging ? 0.92 : 1.0)
            .scaleEffect(isDragging ? 1.02 : 1.0, anchor: .center)
            .animation(isDragging ? .none : MacDesign.springAnimation, value: dragOffsetX)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .scale(scale: 0.85).combined(with: .opacity)
                )
            )
            .id(tab.id)
            .simultaneousGesture(tabDragGesture(for: tab, tabWidth: tabWidth))
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TabFramesKey.self,
                        value: [tab.id: geo.frame(in: .named("top"))]
                    )
                }
            )
        }
    }

    private func offset(forTabAt index: Int, isDragging: Bool) -> CGFloat {
        guard let session = dragSession else { return 0 }
        if isDragging { return session.translation }

        if session.currentIndex > session.startIndex {
            if index > session.startIndex && index <= session.currentIndex {
                return -session.stride
            }
        } else if session.currentIndex < session.startIndex {
            if index >= session.currentIndex && index < session.startIndex {
                return session.stride
            }
        }
        return 0
    }

    private func tabDragGesture(for tab: Tab, tabWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("top"))
            .onChanged { value in
                if dragSession == nil || dragSession?.tabID != tab.id {
                    guard let idx = tabManager.indexOfTab(withID: tab.id)
                    else { return }
                    if tabManager.activeTabID != tab.id { tabManager.switchTo(tab.id) }
                    dragSession = TabDragSession(
                        tabID: tab.id,
                        startIndex: idx,
                        currentIndex: idx,
                        translation: 0,
                        tabWidth: tabWidth
                    )
                }

                dragSession?.translation = value.translation.width
                updateCurrentIndex()
            }
            .onEnded { _ in
                commitReorder()
            }
    }

    private func updateCurrentIndex() {
        guard let session = dragSession else { return }
        let rawShift = Int((session.translation / session.stride).rounded())
        let proposed = session.startIndex + rawShift
        let clamped = min(max(proposed, 0), tabManager.tabs.count - 1)

        if clamped != session.currentIndex {
            withAnimation(MacDesign.springAnimation) {
                dragSession?.currentIndex = clamped
            }
        }
    }

    private func commitReorder() {
        guard let session = dragSession else { return }
        withAnimation(MacDesign.springAnimation) {
            if session.currentIndex != session.startIndex {
                let destination = session.currentIndex > session.startIndex
                    ? session.currentIndex + 1
                    : session.currentIndex
                tabManager.moveTab(
                    fromOffsets: IndexSet(integer: session.startIndex),
                    toOffset: destination
                )
            }
            dragSession = nil
        }
    }

    private var newTabButton: some View {
        Button {
            withAnimation(MacDesign.springAnimation) { _ = tabManager.createTab() }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isNewTabHovered ? Color.textPrimary : Color.textSecondary)
                .frame(width: TabBarMetrics.newTabButtonSize, height: TabBarMetrics.newTabButtonSize)
                .background {
                    Circle().fill(isNewTabHovered ? theme.itemHover : Color.clear)
                }
                .animation(MacDesign.fastAnimation, value: isNewTabHovered)
        }
        .buttonStyle(.plain)
        .onHover { isNewTabHovered = $0 }
        .hoverCursor(.pointingHand)
        .help("New Tab (⌘T)")
        .accessibilityLabel("New Tab")
        .accessibilityIdentifier("browser.tabbar.newTabButton")
        .padding(.leading, TabBarMetrics.tabSpacing)
        .padding(.trailing, 8)
    }
}   