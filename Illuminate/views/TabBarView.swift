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
    static let preferredTabWidth: CGFloat = 200
    static let tabSpacing: CGFloat = 3
    static let scrollThreshold: CGFloat = 72
    static let newTabButtonSize: CGFloat = 28
    static let rowHeight: CGFloat = 42
    static let trafficLightClearance: CGFloat = 78
}

struct HorizontalTabDropDelegate: DropDelegate {
    let targetTab: Tab
    @ObservedObject var tabManager: TabManager
    @Binding var dropTargetID: UUID?
    @Binding var draggedTabID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        defer {
            withAnimation(MacDesign.springAnimation) { dropTargetID = nil }
        }
        guard
            let provider = info.itemProviders(for: ["public.text"]).first
        else { return false }

        provider.loadObject(ofClass: NSString.self) { string, _ in
            guard
                let uuidString = string as? String,
                let sourceID = UUID(uuidString: uuidString),
                sourceID != targetTab.id
            else { return }

            DispatchQueue.main.async {
                if let sourceIndex = tabManager.tabs.firstIndex(where: { $0.id == sourceID }),
                   let targetIndex = tabManager.tabs.firstIndex(where: { $0.id == targetTab.id }) {
                    withAnimation(MacDesign.springAnimation) {
                        tabManager.moveTab(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex)
                    }
                }
                draggedTabID = nil
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        withAnimation(MacDesign.springAnimation) { dropTargetID = targetTab.id }
    }

    func dropExited(info: DropInfo) {
        withAnimation(MacDesign.springAnimation) { dropTargetID = nil }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct TabBarView: View {
    @EnvironmentObject private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var dropTargetID: UUID?
    @State private var draggedTabID: UUID?
    @State private var isNewTabHovered = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            HStack(spacing: 0) {
                tabStrip(availableWidth: availableWidth)
                newTabButton
            }
        }
        .frame(height: TabBarMetrics.rowHeight)
    }

    @ViewBuilder
    private func tabStrip(availableWidth: CGFloat) -> some View {
        let tabs = tabManager.tabs
        let count = max(tabs.count, 1)
        let spacing = TabBarMetrics.tabSpacing * CGFloat(count - 1)
        let newTabRoom = TabBarMetrics.newTabButtonSize + TabBarMetrics.tabSpacing
        let usable = availableWidth - newTabRoom
        let rawWidth = (usable - spacing) / CGFloat(count)
        let computedWidth = min(max(rawWidth, TabBarMetrics.minTabWidth), TabBarMetrics.maxTabWidth)
        let needsScroll = computedWidth <= TabBarMetrics.scrollThreshold

        if needsScroll {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    tabRow(tabWidth: TabBarMetrics.scrollThreshold, proxy: proxy)
                }
                .onChange(of: tabManager.activeTabID) { _, newID in
                    if let id = newID {
                        withAnimation(MacDesign.springAnimation) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        } else {
            tabRow(tabWidth: computedWidth, proxy: nil)
        }
    }

    @ViewBuilder
    private func tabRow(tabWidth: CGFloat, proxy: ScrollViewProxy?) -> some View {
        HStack(spacing: TabBarMetrics.tabSpacing) {
            ForEach(tabManager.tabs) { tab in
                tabItem(tab: tab, width: tabWidth)
                    .id(tab.id)
                    .overlay(alignment: .leading) {
                        if dropTargetID == tab.id, draggedTabID != tab.id {
                            Capsule()
                                .fill(tabManager.windowThemeColor)
                                .frame(width: 2, height: 20)
                                .offset(x: -1)
                                .transition(.opacity.animation(MacDesign.fastAnimation))
                        }
                    }
                    .opacity(draggedTabID == tab.id ? 0.4 : 1.0)
                    .animation(MacDesign.springAnimation, value: draggedTabID)
                    .onDrop(
                        of: ["public.text"],
                        delegate: HorizontalTabDropDelegate(
                            targetTab: tab,
                            tabManager: tabManager,
                            dropTargetID: $dropTargetID,
                            draggedTabID: $draggedTabID
                        )
                    )
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 2)
        .animation(MacDesign.springAnimation, value: tabManager.tabs.map { $0.id })
    }

    private func tabItem(tab: Tab, width: CGFloat) -> some View {
        TabItemView(
            tab: tab,
            themeColor: tabManager.windowThemeColor,
            isActive: tab.id == tabManager.activeTabID,
            onSelect: {
                withAnimation(MacDesign.springAnimation) {
                    tabManager.switchTo(tab.id)
                }
            },
            onClose: {
                withAnimation(MacDesign.springAnimation) {
                    tabManager.closeTab(id: tab.id)
                }
            },
            onDuplicate: {
                if let url = tab.url {
                    tabManager.createTab(url: url)
                }
            },
            onCloseOthers: {
                let othersIDs = tabManager.tabs
                    .filter { $0.id != tab.id }
                    .map { $0.id }
                withAnimation(MacDesign.springAnimation) {
                    othersIDs.forEach { tabManager.closeTab(id: $0) }
                }
            },
            onCloseToRight: {
                guard let idx = tabManager.tabs.firstIndex(where: { $0.id == tab.id }) else { return }
                let rightIDs = tabManager.tabs[(idx + 1)...].map { $0.id }
                withAnimation(MacDesign.springAnimation) {
                    rightIDs.forEach { tabManager.closeTab(id: $0) }
                }
            },
            onCopyLink: {
                guard let url = tab.url?.absoluteString, !url.isEmpty else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            },
            onToggleMute: {
                tab.toggleMute()
            }
        )
        .frame(width: width)
        .onDrag {
            draggedTabID = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        }
    }

    private var newTabButton: some View {
        Button {
            withAnimation(MacDesign.springAnimation) {
                _ = tabManager.createTab()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isNewTabHovered ? Color.textPrimary : Color.textSecondary)
                .frame(width: TabBarMetrics.newTabButtonSize, height: TabBarMetrics.newTabButtonSize)
                .background {
                    Circle()
                        .fill(isNewTabHovered ? theme.itemHover : Color.clear)
                }
                .animation(MacDesign.fastAnimation, value: isNewTabHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isNewTabHovered = hovering
        }
        .hoverCursor(.pointingHand)
        .help("New Tab (⌘T)")
        .accessibilityLabel("New Tab")
        .accessibilityIdentifier("browser.tabbar.newTabButton")
        .padding(.leading, TabBarMetrics.tabSpacing)
        .padding(.trailing, 8)
    }
}
