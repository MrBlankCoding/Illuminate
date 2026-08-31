//
//  NewTabShelfSidebar.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI
import SwiftData

enum ShelfTab: String, CaseIterable, Identifiable {
    case easels, groups, recents
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easels: return "Easels"
        case .groups: return "Groups"
        case .recents: return "Recents"
        }
    }
    var icon: String {
        switch self {
        case .easels: return "paintbrush.pointed.fill"
        case .groups: return "rectangle.3.group.fill"
        case .recents: return "clock.fill"
        }
    }
}

struct NewTabShelfSidebar: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment

    @Binding var selectedTab: ShelfTab
    @Binding var isVisible: Bool

    @Namespace private var tabIndicatorNamespace

    @State private var easelQuery: String = ""
    @State private var groupQuery: String = ""
    @State private var historyQuery: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: MacDesign.Spacing.control) {
                Label(selectedTab.title, systemImage: selectedTab.icon)
                    .font(.webCaptionBold)
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                Spacer()
                shelfActionButton
            }
            .padding(.horizontal, MacDesign.Spacing.regular)
            .padding(.vertical, MacDesign.Spacing.medium)

            shelfTabPicker
            Divider().opacity(0.12)

            Group {
                switch selectedTab {
                case .easels: easelsGridContent
                case .groups: groupsListContent
                case .recents: recentsListContent
                }
            }
            .animation(MacDesign.fastAnimation, value: selectedTab)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var shelfActionButton: some View {
        switch selectedTab {
        case .easels:
            Button {
                let easel = environment.easelManager.createEasel()
                tabManager.createTab(url: easel.url)
            } label: {
                Image(systemName: "plus")
                    .font(.webMicroMedium)
                    .frame(width: MacDesign.Size.urlBarIcon, height: MacDesign.Size.urlBarIcon)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: MacDesign.Spacing.hairlineThin))
            }
            .buttonStyle(.plain)
            .help("New Easel (⇧⌘E)")
            .accessibilityIdentifier("browser.newTab.newEasel.sidebar")
        case .groups:
            Button {
                if let active = tabManager.activeTabID {
                    _ = tabManager.tabGroupManager.createGroup(tabIDs: [active])
                } else {
                    _ = tabManager.tabGroupManager.createGroup()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.webMicroMedium)
                    .frame(width: MacDesign.Size.urlBarIcon, height: MacDesign.Size.urlBarIcon)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: MacDesign.Spacing.hairlineThin))
            }
            .buttonStyle(.plain)
            .help("New Tab Group")
            .accessibilityIdentifier("browser.newTab.newGroup.sidebar")
        case .recents:
            Menu {
                Button("Clear Today") { environment.historyManager.clearToday() }
                Button("Clear All", role: .destructive) { environment.historyManager.clearAll() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.webSmallBold)
                    .frame(width: MacDesign.Size.urlBarIcon, height: MacDesign.Size.urlBarIcon)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: MacDesign.Spacing.hairlineThin))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("History options")
        }
    }

    /// A modern animated capsule switcher, replacing the stock segmented control.
    private var shelfTabPicker: some View {
        HStack(spacing: MacDesign.Spacing.tiny) {
            ForEach(ShelfTab.allCases) { tab in
                let isSelected = tab == selectedTab
                Button {
                    withAnimation(MacDesign.springAnimation) { selectedTab = tab }
                } label: {
                    HStack(spacing: MacDesign.Spacing.tiny) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.title)
                            .font(.webSmallRegularMedium)
                    }
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MacDesign.Spacing.control - 1)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(tabManager.windowThemeColor.opacity(0.32))
                                .matchedGeometryEffect(id: "shelfTabIndicator", in: tabIndicatorNamespace)
                                .overlay(Capsule().stroke(tabManager.windowThemeColor.opacity(0.55), lineWidth: MacDesign.Spacing.hairlineThin))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MacDesign.Spacing.micro)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin))
        .padding(.horizontal, MacDesign.Spacing.regular)
        .padding(.bottom, MacDesign.Spacing.medium)
    }

    private var filteredEasels: [Easel] {
        guard !easelQuery.isEmpty else { return environment.easelManager.easels }
        return environment.easelManager.easels.filter { $0.title.localizedCaseInsensitiveContains(easelQuery) }
    }

    private var easelsGridContent: some View {
        Group {
            if environment.easelManager.easels.isEmpty {
                ShelfEmptyState(
                    icon: "paintbrush.pointed.fill",
                    title: "No easels yet",
                    subtitle: "Create your first whiteboard",
                    accent: tabManager.windowThemeColor
                ) {
                    Button("New Easel") {
                        let easel = environment.easelManager.createEasel()
                        tabManager.createTab(url: easel.url)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .tint(tabManager.windowThemeColor)
                    .padding(.top, MacDesign.Spacing.small)
                }
            } else {
                ScrollView {
                    VStack(spacing: MacDesign.Spacing.small) {
                        ShelfSearchField(
                            text: $easelQuery,
                            placeholder: "Search easels"
                        )
                        .padding(.horizontal, 4)

                        if filteredEasels.isEmpty {
                            ShelfNoMatches(query: easelQuery)
                        } else {
                            LazyVGrid(
                                columns: [
                                    GridItem(
                                        .fixed(200),
                                        spacing: MacDesign.Spacing.small,
                                        alignment: .top
                                    )
                                ],
                                alignment: .center,
                                spacing: MacDesign.Spacing.small
                            ) {
                                ForEach(filteredEasels) { easel in
                                    EaselSidebarCard(easel: easel)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, MacDesign.Spacing.small)
                    .padding(.bottom, MacDesign.Spacing.regular)
                }
            }
        }
    }

    private var filteredGroups: [TabGroup] {
        guard !groupQuery.isEmpty else { return tabManager.tabGroupManager.groups }
        return tabManager.tabGroupManager.groups.filter {
            let name = $0.name.isEmpty ? "Untitled Group" : $0.name
            return name.localizedCaseInsensitiveContains(groupQuery)
        }
    }

    private var groupsListContent: some View {
        Group {
            if tabManager.tabGroupManager.groups.isEmpty {
                ShelfEmptyState(
                    icon: "rectangle.3.group.fill",
                    title: "No tab groups",
                    subtitle: "Group tabs to stay organized",
                    accent: tabManager.windowThemeColor
                ) {
                    Button("New Group") {
                        if let active = tabManager.activeTabID {
                            _ = tabManager.tabGroupManager.createGroup(tabIDs: [active])
                        } else {
                            _ = tabManager.tabGroupManager.createGroup()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .tint(tabManager.windowThemeColor)
                    .padding(.top, MacDesign.Spacing.small)
                }
            } else {
                ScrollView {
                    VStack(spacing: MacDesign.Spacing.small) {
                        ShelfSearchField(text: $groupQuery, placeholder: "Search groups")
                            .padding(.horizontal, 4)

                        if filteredGroups.isEmpty {
                            ShelfNoMatches(query: groupQuery)
                        } else {
                            ForEach(filteredGroups) { group in
                                ShelfGroupCard(group: group)
                            }
                        }
                    }
                    .padding(.bottom, MacDesign.Spacing.regular)
                }
            }
        }
    }

    private var filteredHistory: [HistoryEntry] {
        let entries = Array(environment.historyManager.recentEntries.prefix(40))
        guard !historyQuery.isEmpty else { return entries }
        return entries.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(historyQuery)
                || ($0.url?.host ?? $0.urlString).localizedCaseInsensitiveContains(historyQuery)
        }
    }

    private var recentsListContent: some View {
        Group {
            if environment.historyManager.recentEntries.isEmpty {
                ShelfEmptyState(
                    icon: "clock.fill",
                    title: "No recent history",
                    subtitle: "Pages you visit will appear here",
                    accent: tabManager.windowThemeColor
                )
            } else {
                ScrollView {
                    VStack(spacing: MacDesign.Spacing.small) {
                        ShelfSearchField(text: $historyQuery, placeholder: "Search history")
                            .padding(.horizontal, 4)

                        if filteredHistory.isEmpty {
                            ShelfNoMatches(query: historyQuery)
                        } else {
                            ForEach(filteredHistory) { entry in
                                ShelfRecentRow(entry: entry)
                            }
                        }
                    }
                    .padding(.bottom, MacDesign.Spacing.regular)
                }
            }
        }
    }
}

private struct ShelfSearchField: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: MacDesign.Spacing.control) {
            Image(systemName: "magnifyingglass")
                .font(.webSmallRegular)
                .foregroundStyle(.white.opacity(isFocused ? 0.65 : 0.4))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.webSmallRegular)
                .foregroundStyle(.white.opacity(0.9))
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.webSmallRegular)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, MacDesign.Spacing.regular)
        .padding(.vertical, MacDesign.Spacing.control)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.24) : Color.white.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin)
        )
        .animation(MacDesign.fastAnimation, value: isFocused)
        .animation(MacDesign.fastAnimation, value: text.isEmpty)
    }
}

private struct ShelfNoMatches: View {
    let query: String
    var body: some View {
        VStack(spacing: MacDesign.Spacing.tiny) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text("No matches for \u{201C}\(query)\u{201D}")
                .font(.webSmallRegular)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MacDesign.Spacing.section)
    }
}

private struct ShelfEmptyState<Action: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    @ViewBuilder var action: () -> Action

    init(icon: String, title: String, subtitle: String, accent: Color, @ViewBuilder action: @escaping () -> Action = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.action = action
    }

    var body: some View {
        VStack(spacing: MacDesign.Spacing.tight) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(accent.opacity(0.20), lineWidth: MacDesign.Spacing.hairlineThin)
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: MacDesign.Size.largeIconButton * 0.7, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, MacDesign.Spacing.tiny)

            Text(title)
                .font(.webSmall)
                .foregroundStyle(.white.opacity(0.75))
            Text(subtitle)
                .font(.webSmallRegular)
                .foregroundStyle(.white.opacity(0.45))

            action()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, MacDesign.Spacing.section * 2)
    }
}