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
    static let titleThreshold: CGFloat = 72
    static let tabSpacing: CGFloat = MacDesign.Spacing.tiny
    static let scrollThreshold: CGFloat = 72
    static let newTabButtonSize: CGFloat = MacDesign.Size.iconButton
    static let rowHeight: CGFloat = MacDesign.Size.tabStripHeight
    static let reorderSpring: Animation = .spring(response: 0.26, dampingFraction: 0.85, blendDuration: 0)
    static let swapThreshold: CGFloat = 0.6
    static let detachHapticEngageDistance: CGFloat = 72
    static let detachHapticResetDistance: CGFloat = 32
}

private struct TabDragSession {
    let tabID: UUID
    let startIndex: Int
    var currentIndex: Int      // Where the tab would land if the drag ended now.
    var translation: CGFloat = 0
    let tabWidth: CGFloat
    let spacing: CGFloat = TabBarMetrics.tabSpacing
    var isSettling = false
    var settleAnimation: Animation?

    var stride: CGFloat { tabWidth + spacing }
    var isInteractive: Bool { !isSettling }
    var projectedPosition: CGFloat {
        CGFloat(startIndex) + translation / stride
    }
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
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var dragSession: TabDragSession?
    @State private var isNewTabHovered = false
    @State private var previousActiveTabID: UUID?
    @State private var hasTriggeredDetachHaptic = false
    @Namespace private var activeTabNamespace

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    private var layoutElements: [TabBarElement] {
        var elements: [TabBarElement] = []
        var processedTabIDs = Set<UUID>()
        let groupsManager = tabManager.tabGroupManager

        for tab in tabManager.tabs {
            guard !processedTabIDs.contains(tab.id) else { continue }

            if let group = groupsManager.group(for: tab.id) {
                elements.append(.group(group.id, group.tabIDs))
                processedTabIDs.formUnion(group.tabIDs)
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
                WindowDragArea()
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: TabBarMetrics.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser.tabbar")
        .accessibilityLabel("Tab strip, \(tabManager.tabs.count) \(tabManager.tabs.count == 1 ? "tab" : "tabs")")
    }

    @ViewBuilder
    private func tabStrip(availableWidth: CGFloat) -> some View {
        let tabWidth = idealTabWidth(availableWidth: availableWidth)

        if tabWidth <= TabBarMetrics.scrollThreshold {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    tabRow(tabWidth: TabBarMetrics.scrollThreshold)
                }
                .onChange(of: tabManager.activeTabID) { _, newID in
                    scrollToActiveTab(newID, proxy: proxy)
                }
            }
        } else {
            tabRow(tabWidth: tabWidth)
        }
    }

    private func idealTabWidth(availableWidth: CGFloat) -> CGFloat {
        let count = max(tabManager.tabs.count, 1)
        let newTabRoom = TabBarMetrics.newTabButtonSize + TabBarMetrics.tabSpacing
        let spacing = TabBarMetrics.tabSpacing * CGFloat(count - 1)
        let usable = availableWidth - newTabRoom
        let rawWidth = (usable - spacing) / CGFloat(count)
        return min(max(rawWidth, TabBarMetrics.minTabWidth), TabBarMetrics.maxTabWidth)
    }

    private func scrollToActiveTab(_ newID: UUID?, proxy: ScrollViewProxy) {
        guard newID != previousActiveTabID else { return }
        previousActiveTabID = newID
        guard let id = newID else { return }
        withAnimation(MacDesign.springAnimation) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func tabRow(tabWidth: CGFloat) -> some View {
        let showsTitle = tabWidth >= TabBarMetrics.titleThreshold

        return HStack(spacing: TabBarMetrics.tabSpacing) {
            ForEach(layoutElements) { element in
                switch element {
                case .group(let groupID, let tabIDs):
                    groupView(groupID: groupID, tabIDs: tabIDs, tabWidth: tabWidth, showsTitle: showsTitle)
                case .tab(let tabID):
                    renderTab(tabID: tabID, tabWidth: tabWidth, showsTitle: showsTitle)
                }
            }
        }
        .padding(.vertical, MacDesign.Spacing.small)
        .padding(.leading, MacDesign.Spacing.micro)
    }

    @ViewBuilder
    private func groupView(groupID: UUID, tabIDs: [UUID], tabWidth: CGFloat, showsTitle: Bool) -> some View {
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
                .padding(.trailing, MacDesign.Spacing.micro)
                .padding(.leading, MacDesign.Spacing.micro)

                if !group.isCollapsed {
                    ForEach(tabIDs, id: \.self) { tabID in
                        renderTab(tabID: tabID, tabWidth: tabWidth, showsTitle: showsTitle)
                    }
                }
            }
            .padding(.bottom, MacDesign.Spacing.small)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: MacDesign.Spacing.hairline)
                    .fill(group.groupColor.color)
                    .frame(height: MacDesign.Spacing.micro)
                    .padding(.horizontal, MacDesign.Spacing.small)
            }
        }
    }

    @ViewBuilder
    private func renderTab(tabID: UUID, tabWidth: CGFloat, showsTitle: Bool) -> some View {
        if let tab = tabManager.tab(forID: tabID),
           let index = tabManager.indexOfTab(withID: tabID) {
            let isDragging = dragSession?.tabID == tab.id
            let isLifted = isDragging && dragSession?.isSettling != true
            let dragOffsetX = offset(forTabAt: index, isDragging: isDragging)

            let offsetAnimation: Animation? = isLifted
                ? nil
                : (isDragging ? (dragSession?.settleAnimation ?? TabBarMetrics.reorderSpring) : TabBarMetrics.reorderSpring)

            TabItemView(
                tab: tab,
                themeColor: tabManager.windowThemeColor,
                isActive: tab.id == tabManager.activeTabID,
                showsTitle: showsTitle,
                showsTrailingSeparator: index < tabManager.tabs.count - 1,
                namespace: activeTabNamespace,
                onSelect: { tabManager.switchTo(tab.id) },
                onClose: { tabManager.closeTab(id: tab.id) },
                onDuplicate: {
                    if let url = tab.url { tabManager.createTab(url: url) }
                },
                onCloseOthers: {
                    let ids = tabManager.tabs.filter { $0.id != tab.id }.map { $0.id }
                    ids.forEach { tabManager.closeTab(id: $0) }
                },
                onCloseToRight: {
                    guard let idx = tabManager.indexOfTab(withID: tab.id) else { return }
                    let ids = tabManager.tabs[(idx + 1)...].map { $0.id }
                    ids.forEach { tabManager.closeTab(id: $0) }
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
            .opacity(isLifted ? 0.92 : 1.0)
            .scaleEffect(isLifted ? 1.02 : 1.0, anchor: .center)
            .shadow(color: .black.opacity(isLifted ? 0.15 : 0), radius: isLifted ? 7 : 0, y: isLifted ? 2 : 0)
            .animation(offsetAnimation, value: dragOffsetX)
            .animation(MacDesign.fastAnimation, value: isLifted)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .scale(scale: 0.85).combined(with: .opacity)
                )
            )
            .id(tab.id)
            .simultaneousGesture(tabDragGesture(for: tab, tabWidth: tabWidth))
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
                beginSessionIfNeeded(for: tab, tabWidth: tabWidth)

                guard dragSession?.isInteractive == true else { return }
                dragSession?.translation = value.translation.width

                updateDetachHaptic(verticalTranslation: value.translation.height)
                updateCurrentIndex()
            }
            .onEnded { value in
                hasTriggeredDetachHaptic = false
                commitReorder(predictedEndTranslation: value.predictedEndTranslation.width)
            }
    }

    private func beginSessionIfNeeded(for tab: Tab, tabWidth: CGFloat) {
        guard dragSession == nil || dragSession?.tabID != tab.id else { return }
        guard dragSession?.isSettling != true,
              let idx = tabManager.indexOfTab(withID: tab.id)
        else { return }

        if tabManager.activeTabID != tab.id { tabManager.switchTo(tab.id) }

        dragSession = TabDragSession(
            tabID: tab.id,
            startIndex: idx,
            currentIndex: idx,
            translation: 0,
            tabWidth: tabWidth
        )
        hasTriggeredDetachHaptic = false
    }

    private func updateDetachHaptic(verticalTranslation: CGFloat) {
        let distance = abs(verticalTranslation)

        if !hasTriggeredDetachHaptic && distance > TabBarMetrics.detachHapticEngageDistance {
            hasTriggeredDetachHaptic = true
            HapticFeedback.tabDetached()
        }

        if hasTriggeredDetachHaptic && distance < TabBarMetrics.detachHapticResetDistance {
            hasTriggeredDetachHaptic = false
        }
    }

    private func updateCurrentIndex() {
        guard let session = dragSession, session.isInteractive else { return }

        let position = session.projectedPosition
        var target = session.currentIndex

        if position >= CGFloat(session.currentIndex) + TabBarMetrics.swapThreshold {
            target = session.currentIndex + 1
        } else if position <= CGFloat(session.currentIndex) - TabBarMetrics.swapThreshold {
            target = session.currentIndex - 1
        }

        let clamped = min(max(target, 0), tabManager.tabs.count - 1)
        guard clamped != session.currentIndex else { return }

        HapticFeedback.tabReordered()
        withAnimation(TabBarMetrics.reorderSpring) {
            dragSession?.currentIndex = clamped
        }
    }

    private func commitReorder(predictedEndTranslation: CGFloat) {
        guard var session = dragSession, !session.isSettling else { return }
        session.isSettling = true

        applyFlickIfNeeded(to: &session, predictedEndTranslation: predictedEndTranslation)

        let snappedTranslation = CGFloat(session.currentIndex - session.startIndex) * session.stride
        let distance = abs(snappedTranslation - session.translation)
        let response = min(0.34, max(0.18, distance / 1200))
        let settleAnimation = Animation.spring(response: response, dampingFraction: 0.9)

        dragSession?.settleAnimation = settleAnimation

        withAnimation(settleAnimation) {
            dragSession?.translation = snappedTranslation
            dragSession?.isSettling = true
        } completion: {
            Task { @MainActor in
                finishReorder()
            }
        }
    }

    private func applyFlickIfNeeded(to session: inout TabDragSession, predictedEndTranslation: CGFloat) {
        guard abs(predictedEndTranslation - session.translation) > session.stride * 0.5 else { return }

        let flickIndex = session.startIndex + Int((predictedEndTranslation / session.stride).rounded())
        guard abs(flickIndex - session.currentIndex) == 1 else { return }

        session.currentIndex = min(max(flickIndex, 0), tabManager.tabs.count - 1)
        withAnimation(TabBarMetrics.reorderSpring) {
            dragSession?.currentIndex = session.currentIndex
        }
    }

    private func finishReorder() {
        guard let session = dragSession, session.isSettling else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            moveTabIfNeeded(session)
            assignToNeighboringGroupIfNeeded(session)
            dragSession = nil
        }
    }

    private func moveTabIfNeeded(_ session: TabDragSession) {
        guard session.currentIndex != session.startIndex else { return }
        let destination = session.currentIndex > session.startIndex
            ? session.currentIndex + 1
            : session.currentIndex
        tabManager.moveTab(fromOffsets: IndexSet(integer: session.startIndex), toOffset: destination)
    }

    private func assignToNeighboringGroupIfNeeded(_ session: TabDragSession) {
        let landedIndex = session.currentIndex
        guard let landedTab = tabManager.tabs[safe: landedIndex] else { return }
        guard tabManager.tabGroupManager.group(for: landedTab.id) == nil else { return }

        let neighborGroup = tabManager.tabs[safe: landedIndex - 1].flatMap { tabManager.tabGroupManager.group(for: $0.id) }
            ?? tabManager.tabs[safe: landedIndex + 1].flatMap { tabManager.tabGroupManager.group(for: $0.id) }

        if let targetGroup = neighborGroup {
            tabManager.tabGroupManager.addTabToGroup(landedTab.id, groupID: targetGroup.id)
        }
    }

    private var newTabButton: some View {
        Button {
            HapticFeedback.newTabButtonPressed()
            withAnimation(MacDesign.springAnimation) { _ = tabManager.createTab() }
        } label: {
            Image(systemName: "plus")
                .font(.webMicroMedium)
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
        .padding(.trailing, MacDesign.Spacing.control)
    }
}