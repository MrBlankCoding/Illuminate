//
//  BookmarkBarView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI
import SwiftData

struct BookmarkBarView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.title) private var allBookmarks: [Bookmark]

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    private var bookmarks: [Bookmark] {
        guard !environment.isGuestSession else { return [] }
        let profileID = environment.profile.id
        return allBookmarks.filter { $0.profileID == profileID }
    }

    var body: some View {
        if !bookmarks.isEmpty {
            VStack(spacing: 0) {
                scrollContent
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
            }
            .background(toolbarBackground)
        }
    }

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: MacDesign.Spacing.tight) {
                ForEach(bookmarks) { bookmark in
                    BookmarkItemView(
                        bookmark: bookmark,
                        accentColor: tabManager.windowThemeColor,
                        onOpen: { open(bookmark, inNewTab: false) },
                        onOpenInNewTab: { open(bookmark, inNewTab: true) },
                        onDelete: { delete(bookmark) }
                    )
                }
            }
            .padding(.horizontal, MacDesign.Spacing.regular)
            .padding(.vertical, 5)
        }
        .frame(height: 32)
    }

    private var toolbarBackground: some View {
        Rectangle()
            .fill(.bar)
            .background(theme.toolbarBase)
    }

    private func open(_ bookmark: Bookmark, inNewTab: Bool) {
        guard let url = URL(string: bookmark.url) else { return }
        if inNewTab {
            tabManager.createTab(url: url)
        } else {
            if let activeTab = tabManager.activeTab {
                activeTab.load(url: url)
            } else {
                tabManager.createTab(url: url)
            }
        }
    }

    private func delete(_ bookmark: Bookmark) {
        modelContext.delete(bookmark)
    }
}

private struct BookmarkItemView: View {
    let bookmark: Bookmark
    let accentColor: Color
    let onOpen: () -> Void
    let onOpenInNewTab: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var faviconImage: NSImage?

    private let faviconCache = FaviconCache.shared

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: MacDesign.Spacing.tight - 1) {
                faviconView
                titleText
            }
            .padding(.horizontal, MacDesign.Spacing.control - 1)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(itemFill)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(MacDesign.fastAnimation, value: isPressed)
        .onHover { hovering in
            withAnimation(MacDesign.fastAnimation) { isHovered = hovering }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu { contextMenuItems }
        .task(id: bookmark.url) { await loadFavicon() }
        .accessibilityLabel(bookmark.title.isEmpty ? bookmark.url : bookmark.title)
        .help(bookmark.url)
    }

    private var faviconView: some View {
        Group {
            if let image = faviconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(width: 14, height: 14)
    }

    private var titleText: some View {
        Text(displayTitle)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: 140, alignment: .leading)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Open") { onOpen() }
        Button("Open in New Tab") { onOpenInNewTab() }
        Divider()
        Button("Delete Bookmark", role: .destructive) { onDelete() }
    }

    private var displayTitle: String {
        let t = bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        // Fall back to the bare hostname
        return URL(string: bookmark.url)?.host ?? bookmark.url
    }

    private var itemFill: Color {
        if isPressed {
            return accentColor.opacity(0.18)
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return Color.clear
    }

    private func loadFavicon() async {
        guard let pageURL = URL(string: bookmark.url),
              let scheme = pageURL.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = pageURL.host
        else { return }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/favicon.ico"
        guard let faviconURL = components.url else { return }

        let image = await faviconCache.fetchImage(for: faviconURL)
        await MainActor.run { faviconImage = image }
    }
}
