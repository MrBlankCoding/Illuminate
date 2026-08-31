//
//  NewTabShelfCards.swift
//  Illuminate
//
//  Cards used inside the New Tab Shelf (Easels / Groups / Recents).
//

import SwiftUI

struct EaselSidebarCard: View {
    let easel: Easel
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @State private var isHovered = false

    var body: some View {
        Button {
            tabManager.createTab(url: easel.url)
        } label: {
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    if let preview = environment.easelManager.previewImage(for: easel.id) {
                        Image(nsImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: MacDesign.Radius.small)
                            .fill(
                                LinearGradient(
                                    colors: [tabManager.windowThemeColor.opacity(0.20), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: MacDesign.Size.largeIconButton * 0.55, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: MacDesign.Spacing.tiny) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(easel.title)
                        .font(.webSmall)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.6), radius: MacDesign.Spacing.micro, y: MacDesign.Spacing.hairline)
                .padding(.horizontal, MacDesign.Spacing.small)
                .padding(.vertical, MacDesign.Spacing.small)
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MacDesign.Radius.medium).stroke(Color.white.opacity(0.10), lineWidth: MacDesign.Spacing.hairlineThin))
            .shadow(color: .black.opacity(isHovered ? 0.22 : 0.10), radius: isHovered ? MacDesign.Spacing.regular : MacDesign.Spacing.small, y: isHovered ? MacDesign.Spacing.small : MacDesign.Spacing.micro)
            .overlay(RoundedRectangle(cornerRadius: MacDesign.Radius.medium).stroke(isHovered ? tabManager.windowThemeColor.opacity(0.5) : Color.clear, lineWidth: MacDesign.Spacing.hairlineThin))
            .scaleEffect(isHovered ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .animation(MacDesign.springAnimation, value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { tabManager.createTab(url: easel.url) }
            Button("Rename…") {
                let alert = NSAlert()
                alert.messageText = "Rename Easel"
                alert.informativeText = "Enter new title:"
                let field = NSTextField(frame: NSRect(x: 0, y: 0, width: MacDesign.Size.sidePanelWidth - MacDesign.Spacing.regular, height: MacDesign.Size.urlBarHeight * 0.7))
                field.stringValue = easel.title
                alert.accessoryView = field
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    environment.easelManager.renameEasel(id: easel.id, to: field.stringValue)
                }
            }
            Divider()
            Button("Delete Easel", role: .destructive) {
                environment.easelManager.deleteEasel(id: easel.id)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovered {
                Button {
                    environment.easelManager.deleteEasel(id: easel.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.webTinyBold)
                        .foregroundStyle(.white)
                        .frame(width: MacDesign.Size.iconButton * 0.64, height: MacDesign.Size.iconButton * 0.64)
                        .background(Color.red.opacity(0.9), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: MacDesign.Spacing.hairlineThin))
                }
                .buttonStyle(.plain)
                .padding(MacDesign.Spacing.small)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .help("Open \(easel.title)")
    }
}

struct ShelfGroupCard: View {
    let group: TabGroup
    @Environment(TabManager.self) private var tabManager: TabManager
    @State private var isHovered = false

    private var memberTabs: [Tab] {
        group.tabIDs.compactMap { tabManager.tabIndex[$0] }
    }

    private var pillFill: Color {
        group.groupColor.color.opacity(0.18)
    }

    private var pillStroke: Color {
        group.groupColor.color.opacity(0.34)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(MacDesign.springAnimation) {
                    tabManager.tabGroupManager.toggleCollapse(group.id)
                }
            } label: {
                HStack(spacing: MacDesign.Spacing.control) {
                    Circle()
                        .fill(group.groupColor.color)
                        .frame(width: MacDesign.Spacing.mini + 2, height: MacDesign.Spacing.mini + 2)
                        .shadow(color: group.groupColor.color.opacity(0.6), radius: MacDesign.Spacing.tiny)

                    Text(group.name.isEmpty ? "Untitled Group" : group.name)
                        .font(.webSmallRegularMedium)
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    if !memberTabs.isEmpty {
                        Text("\(memberTabs.count)")
                            .font(.webTinyBold)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, MacDesign.Spacing.tight)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .rotationEffect(.degrees(group.isCollapsed ? 0 : 90))
                }
                .padding(.horizontal, MacDesign.Spacing.regular)
                .padding(.vertical, MacDesign.Spacing.small + 2)
                .background(pillFill, in: Capsule())
                .overlay(Capsule().stroke(pillStroke, lineWidth: MacDesign.Spacing.hairlineThin))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(group.isCollapsed ? "Expand" : "Collapse")

            if !group.isCollapsed, !memberTabs.isEmpty {
                Divider().opacity(0.08)
                VStack(alignment: .leading, spacing: MacDesign.Spacing.micro) {
                    ForEach(memberTabs, id: \.id) { tab in
                        Button {
                            tabManager.switchTo(tab.id)
                        } label: {
                            HStack(spacing: MacDesign.Spacing.control) {
                                RoundedRectangle(cornerRadius: MacDesign.Radius.micro)
                                    .fill(tabManager.activeTabID == tab.id ? group.groupColor.color : Color.clear)
                                    .frame(width: MacDesign.Spacing.hairline + 1)
                                    .frame(maxHeight: .infinity)
                                    .padding(.vertical, 2)

                                if let fav = tab.favicon {
                                    Image(nsImage: fav).resizable().aspectRatio(contentMode: .fit).frame(width: MacDesign.Spacing.regular + 2, height: MacDesign.Spacing.regular + 2).clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.micro, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: MacDesign.Radius.micro).fill(Color.white.opacity(0.12)).frame(width: MacDesign.Spacing.regular + 2, height: MacDesign.Spacing.regular + 2)
                                        .overlay(Text(String((tab.title.first ?? "?").uppercased()).prefix(1)).font(.webTinyBold).foregroundStyle(.white.opacity(0.7)))
                                }
                                Text(tab.title.isEmpty ? (tab.url?.host ?? "New Tab") : tab.title)
                                    .font(.webSmallRegular)
                                    .lineLimit(1)
                                    .foregroundStyle(.white.opacity(0.88))
                                Spacer()
                                if tabManager.activeTabID == tab.id {
                                    Circle().fill(Color.white.opacity(0.9)).frame(width: MacDesign.Spacing.mini, height: MacDesign.Spacing.mini)
                                }
                            }
                            .padding(.horizontal, MacDesign.Spacing.control)
                            .padding(.vertical, MacDesign.Spacing.mini)
                            .background(tabManager.activeTabID == tab.id ? Color.white.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: MacDesign.Radius.small))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, MacDesign.Spacing.tight)
                .padding(.horizontal, MacDesign.Spacing.small)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(MacDesign.Spacing.control)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: MacDesign.Radius.medium).stroke(isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin))
        .shadow(color: .black.opacity(isHovered ? 0.16 : 0.08), radius: isHovered ? MacDesign.Spacing.regular : MacDesign.Spacing.small, y: isHovered ? MacDesign.Spacing.small : MacDesign.Spacing.micro)
        .animation(MacDesign.springAnimation, value: group.isCollapsed)
        .animation(MacDesign.fastAnimation, value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(group.isCollapsed ? "Expand" : "Collapse") { withAnimation(MacDesign.springAnimation) { tabManager.tabGroupManager.toggleCollapse(group.id) } }
            Divider()
            ForEach(TabGroupColor.allCases) { col in
                Button {
                    tabManager.tabGroupManager.changeGroupColor(group.id, to: col)
                } label: {
                    Label(col.displayName, systemImage: group.groupColor == col ? "checkmark" : "")
                }
            }
            Divider()
            Button("Close Group", role: .destructive) { tabManager.tabGroupManager.closeGroup(group.id, tabs: tabManager.tabs) }
            Button("Delete Group", role: .destructive) { tabManager.tabGroupManager.deleteGroup(group.id) }
        }
    }
}

struct ShelfRecentRow: View {
    let entry: HistoryEntry
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @State private var isHovered = false
    @State private var favicon: NSImage?

    var body: some View {
        Button {
            if let url = entry.url { tabManager.createTab(url: url) }
        } label: {
            HStack(spacing: MacDesign.Spacing.control) {
                ZStack {
                    RoundedRectangle(cornerRadius: MacDesign.Radius.small)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: MacDesign.Radius.small).stroke(Color.white.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin))
                        .frame(width: MacDesign.Size.urlBarIcon, height: MacDesign.Size.urlBarIcon)
                    if let favicon {
                        Image(nsImage: favicon).resizable().aspectRatio(contentMode: .fit).frame(width: MacDesign.Spacing.regular + 2, height: MacDesign.Spacing.regular + 2).clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.micro))
                    } else {
                        Text(monogram)
                            .font(.webTinyBold)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                VStack(alignment: .leading, spacing: MacDesign.Spacing.hairline) {
                    Text(entry.displayTitle)
                        .font(.webSmall)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    Text(hostText)
                        .font(.webSmall)
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text(relativeLabel)
                    .font(.webTinyBold)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, MacDesign.Spacing.tight)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(isHovered ? 0.08 : 0), in: Capsule())
            }
            .padding(.horizontal, MacDesign.Spacing.small + 1)
            .padding(.vertical, MacDesign.Spacing.tight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.control))
            .overlay(RoundedRectangle(cornerRadius: MacDesign.Radius.control).fill(isHovered ? Color.white.opacity(0.07) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: MacDesign.Radius.control).stroke(isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.06), lineWidth: MacDesign.Spacing.hairlineThin))
        }
        .buttonStyle(.plain)
        .animation(MacDesign.fastAnimation, value: isHovered)
        .onHover { isHovered = $0 }
        .task(id: entry.faviconURLString) { await loadFavicon() }
        .contextMenu {
            Button("Open") { if let url = entry.url { tabManager.createTab(url: url) } }
            Button("Open in Background") { if let url = entry.url { tabManager.createTab(url: url, inBackground: true) } }
            Divider()
            Button("Copy Link") { if let url = entry.url { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.absoluteString, forType: .string) } }
            Divider()
            Button("Delete", role: .destructive) { environment.historyManager.delete(id: entry.id) }
        }
        .help(entry.urlString)
    }

    private var monogram: String { String(entry.displayTitle.prefix(1)).uppercased() }
    private var hostText: String { entry.url?.host ?? entry.urlString }
    private var relativeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(entry.lastVisited) { return "Today" }
        if cal.isDateInYesterday(entry.lastVisited) { return "Yesterday" }
        let d = cal.dateComponents([.day], from: entry.lastVisited, to: Date()).day ?? 0
        if d < 7 { return "\(d)d ago" }
        return RelativeDateTimeFormatter().localizedString(for: entry.lastVisited, relativeTo: Date())
    }
    private func loadFavicon() async {
        guard let favURL = entry.faviconURL else {
            guard let host = entry.url?.host, let url = URL(string: "https://\(host)/favicon.ico") else { return }
            favicon = await FaviconLoader.shared.loadFavicon(from: url)
            return
        }
        favicon = await FaviconLoader.shared.loadFavicon(from: favURL)
    }
}