//
//  TabDisplayView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct TabDisplayView: View {
    @EnvironmentObject private var environment: ProfileEnvironment
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var viewModel: ContentViewModel
    @EnvironmentObject private var urlSynchronizer: URLSynchronizer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.title) private var allBookmarks: [Bookmark]
    @Binding var hoveredSidebarTabID: UUID?
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var hoveredTabID: UUID?
    @State private var hoveredNewTabButton = false
    @State private var dropTargetID: UUID?
    
    @State private var showingCreateGroup = false
    @State private var newGroupName = ""
    @State private var newGroupColor = "89BBFF"

    private var bookmarks: [Bookmark] {
        guard environment.isGuestSession == false else { return [] }
        return allBookmarks.filter { $0.profileID == environment.profile.id }
    }

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                }
                .frame(height: 38) // native window buttons fall here
                .background(DraggableArea())
                
                CavedDivider()
                    .padding(.bottom, 2)
                    
            ScrollView(.vertical, showsIndicators: false) {
                sidebarContent
                    .padding(.vertical, 6)
            }
            .layoutPriority(1)

            VStack(spacing: 0) {
                if tabManager.sidebarPanel == .tabs, !bookmarks.isEmpty {
                    CavedDivider()
                        .padding(.bottom, 2)
                    bookmarkDock
                        .padding(.bottom, 12)
                }

                SidebarFooter(activeTab: tabManager.activeTab)
            }
            .padding(.bottom, 12)
        }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            .contextMenu {
                if tabManager.sidebarPanel == .tabs {
                    Button("Create Tab Group") {
                        newGroupName = ""
                        showingCreateGroup = true
                    }
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
                SidebarBackground(theme: theme)
                    .ignoresSafeArea()
            }
        )
        .overlay(
            Rectangle()
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
                .padding(.top, -1)
        )
    }

    @ViewBuilder
    private var sidebarContent: some View {
        switch tabManager.sidebarPanel {
        case .tabs:
            tabsListContent
        case .downloads:
            downloadsListContent
        }
    }

    private var tabsListContent: some View {
        let ungroupedTabs = tabManager.tabs.filter { $0.groupID == nil }
        
        return LazyVStack(alignment: .leading, spacing: 5) {
            newTabButton
            ForEach(tabManager.tabGroups) { group in
                TabGroupSection(group: group, hoveredSidebarTabID: $hoveredSidebarTabID)
            }

            ForEach(ungroupedTabs) { tab in
                VStack(spacing: 0) {
                    if dropTargetID == tab.id {
                        insertionIndicator
                    }
                    tabRow(tab: tab)
                        .background(alignment: .bottom) {
                            if tab.id != ungroupedTabs.last?.id {
                                Rectangle()
                                    .fill(tabManager.windowThemeColor.opacity(0.5))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                                    .offset(y: 3)
                            }
                        }
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

    private var downloadsListContent: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            downloadsHeader

            if downloadManager.downloads.isEmpty {
                downloadsEmptyState
            } else {
                ForEach(downloadManager.downloads) { task in
                    SidebarDownloadRow(task: task, themeColor: tabManager.windowThemeColor)
                }
            }
        }
        .padding(.bottom, 12)
        .contentShape(Rectangle())
    }

    private var downloadsHeader: some View {
        HStack(spacing: 8) {
            Label("Downloads", systemImage: "arrow.down.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if !downloadManager.downloads.isEmpty {
                Button("Clear") {
                    downloadManager.clearFinishedDownloads()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var downloadsEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 28))
                .foregroundStyle(Color.textSecondary.opacity(0.6))

            Text("No downloads yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("Files you download will appear here.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
    }
    
    private var insertionIndicator: some View {
        Capsule()
            .fill(tabManager.windowThemeColor)
            .frame(height: 2)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .transition(.scale.combined(with: .opacity))
    }
    // new tab or tab new?
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hoveredNewTabButton ? theme.itemHover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    .foregroundStyle(Color.borderSubtle.opacity(hoveredNewTabButton ? 1.0 : 0.55))
            )
            .animation(.easeInOut(duration: 0.15), value: hoveredNewTabButton)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("browser.sidebar.newTabButton")
        .onHover { hovering in
            hoveredNewTabButton = hovering
        }
    }
    
    @ViewBuilder
    private func tabRow(tab: Tab) -> some View {
        SidebarTabRow(
            tab: tab,
            themeColor: tabManager.windowThemeColor,
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
                hoveredSidebarTabID = hoveredTabID
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
        
        urlSynchronizer.updateCurrentURL(url)
        viewModel.addressBarText = url.absoluteString
    }

    private func toggleBookmark(from tab: Tab) {
        guard environment.isGuestSession == false else {
            return
        }

        guard let url = tab.url?.absoluteString, !url.isEmpty else {
            return
        }

        let title = tab.title.isEmpty ? url : tab.title
        if let existingBookmark = bookmarks.first(where: { $0.url == url }) {
            modelContext.delete(existingBookmark)
        } else {
            modelContext.insert(Bookmark(profileID: environment.profile.id, title: title, url: url))
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

private struct SidebarDownloadRow: View {
    let task: DownloadTask
    let themeColor: Color

    var body: some View {
        HStack(spacing: 10) {
            fileIcon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(task.filename)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if task.state == .completed, task.destinationURL != nil {
                        Button("Open in Finder") {
                            DownloadManager.shared.revealDownload(task)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(themeColor)
                    } else if task.isActive {
                        Button("Cancel") {
                            DownloadManager.shared.cancelDownload(id: task.id)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 8) {
                    Text(secondaryText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(stateLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(statusTint.opacity(0.12))
                        .clipShape(Capsule())
                }

                if task.isActive {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                        .tint(themeColor)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }

    private var fileIcon: some View {
        Image(nsImage: resolvedFileIcon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 28, height: 28)
    }

    private var stateLabel: String {
        switch task.state {
        case .preparing:
            return "Preparing"
        case .downloading:
            return "Downloading"
        case .completed:
            return "Complete"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private var secondaryText: String {
        switch task.state {
        case .completed:
            if let destinationURL = task.destinationURL {
                return destinationURL.deletingLastPathComponent().lastPathComponent
            }
            return "Completed"
        default:
            return task.statusDescription
        }
    }

    private var statusTint: Color {
        switch task.state {
        case .completed:
            return .green
        case .failed, .cancelled:
            return .red
        case .preparing, .downloading:
            return themeColor
        }
    }

    private var resolvedFileIcon: NSImage {
        if let destinationURL = task.destinationURL {
            return NSWorkspace.shared.icon(forFile: destinationURL.path)
        }

        let fileExtension = (task.filename as NSString).pathExtension
        if let contentType = UTType(filenameExtension: fileExtension), !fileExtension.isEmpty {
            return NSWorkspace.shared.icon(for: contentType)
        }

        return NSWorkspace.shared.icon(for: .data)
    }
}

private struct SidebarBackground: View {
    let theme: BrowserTheme

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
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
        withAnimation(.spring(response: 0.25)) {
            dropTargetID = nil
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct TabGroupSection: View {
    @EnvironmentObject private var tabManager: TabManager
    let group: TabGroup
    @Binding var hoveredSidebarTabID: UUID?
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
                    let groupedTabs = tabManager.tabs.filter { $0.groupID == group.id }
                    ForEach(groupedTabs) { tab in
                        SidebarTabRow(
                            tab: tab,
                            themeColor: tabManager.windowThemeColor,
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
                                hoveredSidebarTabID = hoveredTabID
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
                        .background(alignment: .bottom) {
                            if tab.id != groupedTabs.last?.id {
                                Rectangle()
                                    .fill(tabManager.windowThemeColor.opacity(0.5))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                                    .offset(y: 2.5)
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
                    .foregroundStyle(name.isEmpty ? Color.textSecondary : .white)
                    .background(Color(hex: color).opacity(name.isEmpty ? 0.3 : 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(name.isEmpty)
                    .animation(.easeInOut(duration: 0.15), value: name.isEmpty)
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
                    .fill(Color.primary.opacity(0.06))
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
                    .strokeBorder(isHovered ? Color.borderSubtle : Color.clear, lineWidth: 1)
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
