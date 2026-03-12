//
//  TabDisplayView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import SwiftData
import AppKit

struct TabDisplayView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var viewModel: ContentViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.title) private var bookmarks: [Bookmark]
    @State private var hoveredTabID: UUID?
    @State private var hoveredNewTabButton = false
    @State private var dropTargetID: UUID?
    
    @State private var showingCreateGroup = false
    @State private var newGroupName = ""
    @State private var newGroupColor = "89BBFF"

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                TrafficLightsView()
                    .padding(.leading, 4)
                
                Spacer()
                
                if let activeTab = tabManager.activeTab {
                    NavigationControls(tab: activeTab, showsRefreshButton: true)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").opacity(0.2)
                        Image(systemName: "chevron.right").opacity(0.2)
                        Image(systemName: "arrow.clockwise").opacity(0.2)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
            URLBar(
                activeTab: tabManager.activeTab,
                addressText: $viewModel.addressBarText,
                onNavigate: viewModel.navigateToAddressBarURL
            )
            .padding(.bottom, 12)

            CavedDivider()
            ScrollView(.vertical, showsIndicators: false) {
                tabsListContent
                    .padding(.vertical, 10)
            }
            .layoutPriority(1)
            VStack(spacing: 0) {
                if !bookmarks.isEmpty {
                    CavedDivider()
                        .padding(.bottom, 2)
                    bookmarkDock
                        .padding(.bottom, 12)
                }

                SidebarFooter(activeTab: tabManager.activeTab)
            }
            .padding(.bottom, 12)
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            .contextMenu {
                Button("Create Tab Group") {
                    newGroupName = ""
                    showingCreateGroup = true
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateTabGroupView(name: $newGroupName, color: $newGroupColor) {
                    tabManager.createTabGroup(name: newGroupName, color: newGroupColor)
                    showingCreateGroup = false
                }
            }
        }
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)

                tabManager.windowThemeColor.opacity(0.12)

                EllipticalGradient(
                    gradient: Gradient(colors: [
                        tabManager.windowThemeColor.opacity(0.4),
                        tabManager.windowThemeColor.opacity(0.15),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadiusFraction: 0,
                    endRadiusFraction: 1.2
                )
            }
        )
        .overlay(
            Rectangle()
                .strokeBorder(Color.borderGlass, lineWidth: 1)
                .padding(.top, -1)
        )
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkTab)) { _ in
            if let activeTab = tabManager.activeTab {
                toggleBookmark(from: activeTab)
            }
        }
    }

    private var tabsListContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            newTabButton
            ForEach(tabManager.tabGroups) { group in
                TabGroupSection(group: group)
            }

            ForEach(tabManager.tabs.filter { $0.groupID == nil }) { tab in
                VStack(spacing: 0) {
                    if dropTargetID == tab.id {
                        insertionIndicator
                    }
                    tabRow(tab: tab)
                }
            }
            
            Color.clear
                .frame(height: 10)
                .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                    handleDropAtEnd(providers)
                    return true
                }
        }
        .padding(.bottom, 12)
        .contentShape(Rectangle())
    }
    
    private var insertionIndicator: some View {
        Capsule()
            .fill(tabManager.windowThemeColor)
            .frame(height: 2)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .transition(.scale.combined(with: .opacity))
    }
    
    private var newTabButton: some View {
        Button {
            tabManager.createTab()
        } label: {
            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 4, height: 20)

                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 18, height: 18)

                Text("New Tab")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hoveredNewTabButton ? Color.bgSurface.opacity(0.5) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    .foregroundStyle(Color.borderGlass.opacity(hoveredNewTabButton ? 1.0 : 0.5))
            )
            .scaleEffect(hoveredNewTabButton ? 1.02 : 1.0)
            .shadow(
                color: hoveredNewTabButton ? tabManager.windowThemeColor.opacity(0.18) : .clear,
                radius: hoveredNewTabButton ? 8 : 0,
                y: hoveredNewTabButton ? 2 : 0
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: hoveredNewTabButton)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredNewTabButton = hovering
        }
    }
    
    @ViewBuilder
    private func tabRow(tab: Tab) -> some View {
        SidebarTabRow(
            tab: tab,
            isActive: tab.id == tabManager.activeTabID,
            isHovered: hoveredTabID == tab.id,
            onSelect: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    tabManager.switchTo(tab.id)
                }
            },
            onClose: {
                tabManager.closeTab(id: tab.id)
            },
            onCopyLink: {
                copyToPasteboard(tab.url?.absoluteString ?? "")
            },
            onBookmark: {
                toggleBookmark(from: tab)
            }
        )
        .anchorPreference(key: TabRowFramePreferenceKey.self, value: .bounds) { (anchor: Anchor<CGRect>) -> [UUID: Anchor<CGRect>] in
            [tab.id: anchor]
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                hoveredTabID = hovering ? tab.id : nil
                tabManager.hoveredSidebarTabID = hoveredTabID
            }
        }
        .onDrag {
            NSItemProvider(object: tab.id.uuidString as NSString)
        }
        .onDrop(of: ["public.text"], delegate: TabDropDelegate(targetTab: tab, tabManager: tabManager, dropTargetID: $dropTargetID))
    }

    private var bookmarkDock: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(bookmarks) { bookmark in
                bookmarkIcon(bookmark)
                    .contextMenu {
                        Button("Remove Bookmark", role: .destructive) {
                            modelContext.delete(bookmark)
                        }
                    }
            }
        }
        .padding(.horizontal, 4)
        .opacity(bookmarks.isEmpty ? 0 : 1)
        .animation(.easeInOut(duration: 0.15), value: bookmarks.count)
    }

    private func bookmarkIcon(_ bookmark: Bookmark) -> some View {
        BookmarkIconButton(
            bookmark: bookmark,
            fallbackFavicon: fallbackFavicon,
            faviconURL: bookmarkFaviconURL(for: bookmark.url),
            action: { openBookmark(bookmark) }
        )
    }

    private var fallbackFavicon: Image {
        Image(systemName: "globe")
    }

    private func bookmarkFaviconURL(for bookmarkURL: String) -> URL? {
        guard
            let pageURL = URL(string: bookmarkURL),
            let host = pageURL.host
        else {
            return nil
        }

        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }

    private func openBookmark(_ bookmark: Bookmark) {
        guard let url = URL(string: bookmark.url) else {
            return
        }

        if let activeTab = tabManager.activeTab, activeTab.url == nil {
            tabManager.updateTabURL(tabID: activeTab.id, url: url)
        } else {
            tabManager.createTab(url: url)
        }
        
        URLSynchronizer.shared.updateCurrentURL(url)
        viewModel.addressBarText = url.absoluteString
    }

    private func toggleBookmark(from tab: Tab) {
        guard let url = tab.url?.absoluteString, !url.isEmpty else {
            return
        }

        let title = tab.title.isEmpty ? url : tab.title
        if let existingBookmark = bookmarks.first(where: { $0.url == url }) {
            modelContext.delete(existingBookmark)
        } else {
            modelContext.insert(Bookmark(title: title, url: url))
        }
    }

    private func copyToPasteboard(_ value: String) {
        guard !value.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
    
    private func handleDropAtEnd(_ providers: [NSItemProvider]) {
        providers.first?.loadObject(ofClass: NSString.self) { string, _ in
            if let uuidString = string as? String, let sourceID = UUID(uuidString: uuidString) {
                DispatchQueue.main.async {
                    if let sourceIndex = tabManager.tabs.firstIndex(where: { $0.id == sourceID }) {
                        withAnimation(.spring(response: 0.35)) {
                            tabManager.moveTab(fromOffsets: IndexSet(integer: sourceIndex), toOffset: tabManager.tabs.count)
                        }
                    }
                }
            }
        }
    }
}

struct TabDropDelegate: DropDelegate {
    let targetTab: Tab
    let tabManager: TabManager
    @Binding var dropTargetID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        info.itemProviders(for: ["public.text"]).first?.loadObject(ofClass: NSString.self) { string, _ in
            if let uuidString = string as? String, let sourceID = UUID(uuidString: uuidString) {
                DispatchQueue.main.async {
                    if let sourceIndex = tabManager.tabs.firstIndex(where: { $0.id == sourceID }),
                       let targetIndex = tabManager.tabs.firstIndex(where: { $0.id == targetTab.id }) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            tabManager.moveTab(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex)
                        }
                    }
                    dropTargetID = nil
                }
            }
        }
        return true
    }
    
    func dropEntered(info: DropInfo) {
        withAnimation(.spring(response: 0.25)) {
            dropTargetID = targetTab.id
        }
    }
    
    func dropExited(info: DropInfo) {
        // Only clear if we are moving out of the entire area?
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct TabGroupSection: View {
    @EnvironmentObject var tabManager: TabManager
    let group: TabGroup
    @State private var isHovered = false
    @State private var hoveredTabID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: group.color))
                
                Text(group.name.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: group.color))
                    .kerning(1.0)
                
                Spacer()
                
                if isHovered {
                    Button {
                        tabManager.removeTabGroup(id: group.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    tabManager.toggleGroupExpansion(id: group.id)
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                providers.first?.loadObject(ofClass: NSString.self) { string, _ in
                    if let uuidString = string as? String, let uuid = UUID(uuidString: uuidString) {
                        DispatchQueue.main.async {
                            tabManager.setTabGroup(tabID: uuid, groupID: group.id)
                        }
                    }
                }
                return true
            }

            if group.isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tabManager.tabs.filter { $0.groupID == group.id }) { tab in
                        SidebarTabRow(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabID,
                            isHovered: hoveredTabID == tab.id,
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                    tabManager.switchTo(tab.id)
                                }
                            },
                            onClose: {
                                tabManager.closeTab(id: tab.id)
                            },
                            onCopyLink: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(tab.url?.absoluteString ?? "", forType: .string)
                            },
                            onBookmark: {
                                // Bookmark logic if needed
                            }
                        )
                        .anchorPreference(key: TabRowFramePreferenceKey.self, value: .bounds) { (anchor: Anchor<CGRect>) -> [UUID: Anchor<CGRect>] in
                            [tab.id: anchor]
                        }
                        .padding(.leading, 12)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.16)) {
                                hoveredTabID = hovering ? tab.id : nil
                                tabManager.hoveredSidebarTabID = hoveredTabID
                            }
                        }
                        .onDrag {
                            NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .contextMenu {
                            Button("Ungroup Tab") {
                                tabManager.setTabGroup(tabID: tab.id, groupID: nil)
                            }
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: group.color).opacity(0.12))
        )
    }
}

struct CreateTabGroupView: View {
    @Binding var name: String
    @Binding var color: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    let colors = ["89BBFF", "FF8989", "89FFB1", "FF89F1", "FFD189", "A189FF"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Tab Group")
                .font(.webH2)
            
            TextField("Group Name", text: $name)
                .textFieldStyle(.plain)
                .padding(10)
                .glassBackground()
            
            HStack(spacing: 15) {
                ForEach(colors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: color == hex ? 2 : 0)
                        )
                        .onTapGesture {
                            color = hex
                        }
                }
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") { onSave() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: color))
                    .cornerRadius(8)
                    .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
        .glassBackground()
    }
}

private struct BookmarkIconButton: View {
    @EnvironmentObject private var tabManager: TabManager
    let bookmark: Bookmark
    let fallbackFavicon: Image
    let faviconURL: URL?
    let action: () -> Void
    @State private var isHovered = false
    @State private var faviconImage: NSImage?

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.bgSurface.opacity(0.75))
                    .frame(width: 36, height: 36)

                if let faviconImage {
                    Image(nsImage: faviconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } else {
                    fallbackFavicon
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tabManager.windowThemeColor)
                }
            }
            .background(
                Circle()
                    .fill(isHovered ? tabManager.windowThemeColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                Circle()
                    .strokeBorder(isHovered ? Color.borderGlass : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.14), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadFavicon()
        }
        .hoverCursor(.pointingHand)
        .help(bookmark.title.isEmpty ? bookmark.url : bookmark.title)
    }

    private func loadFavicon() {
        guard let url = faviconURL else { return }
        Task {
            if let image = await FaviconCache.shared.fetchImage(for: url) {
                self.faviconImage = image
            }
        }
    }
}
