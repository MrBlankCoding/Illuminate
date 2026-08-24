//
//  NewTabView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftData
import SwiftUI

struct NewTabView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.title) private var allBookmarks: [Bookmark]
    @State private var isCustomizePanelShown = false
    @State private var hasAppeared = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    private var bookmarks: [Bookmark] {
        guard !environment.isGuestSession else { return [] }
        return allBookmarks.filter { $0.profileID == environment.profile.id }
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 48) {
                        Spacer(minLength: 72)
                        header
                        bookmarkGrid
                        Spacer(minLength: 72)
                    }
                    .frame(maxWidth: .infinity, minHeight: 480)
                    .padding(.horizontal, 32)
                }
                .scrollIndicators(.hidden)

                customizeButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isCustomizePanelShown {
                NewTabCustomizePanel()
                    .environmentObject(tabManager)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
        .ignoresSafeArea()
        .preferredColorScheme(tabManager.userInterfaceStyle.colorScheme)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            // should change the font or remove entierly
            Text("Illuminate")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.32), radius: 10, y: 2)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 6)
    }

    @ViewBuilder
    private var bookmarkGrid: some View {
        if !environment.isGuestSession {
            Group {
                if bookmarks.isEmpty {
                    emptyState
                } else {
                    GlassEffectContainer(spacing: NewTabLayout.gridSpacing) {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: NewTabLayout.tileWidth, maximum: NewTabLayout.tileWidth), spacing: NewTabLayout.gridSpacing)
                            ],
                            alignment: .center,
                            spacing: NewTabLayout.gridSpacing
                        ) {
                            ForEach(bookmarks) { bookmark in
                                NewTabBookmarkCard(
                                    bookmark: bookmark,
                                    accentColor: tabManager.windowThemeColor,
                                    onOpen: { open(bookmark, inNewTab: false) },
                                    onOpenInNewTab: { open(bookmark, inNewTab: true) },
                                    onDelete: { modelContext.delete(bookmark) },
                                    onRename: { newTitle in
                                        bookmark.title = newTitle
                                        try? modelContext.save()
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: 560)
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            VStack(spacing: 4) {
                Text("No Bookmarks Yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Bookmark a page with ⌘B and it will appear here.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        }
        .frame(maxWidth: 340)
    }

    private var customizeButton: some View {
        Button {
            withAnimation(MacDesign.springAnimation) {
                isCustomizePanelShown.toggle()
            }
        } label: {
            Image(systemName: isCustomizePanelShown ? "xmark" : "pencil")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(
                    isCustomizePanelShown
                        ? AnyShapeStyle(tabManager.windowThemeColor.opacity(0.85))
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
                .foregroundStyle(isCustomizePanelShown ? .white : .white.opacity(0.9))
                .overlay {
                    Circle()
                        .stroke(
                            isCustomizePanelShown
                                ? tabManager.windowThemeColor
                                : Color.white.opacity(0.18),
                            lineWidth: 0.5
                        )
                }
                .shadow(
                    color: isCustomizePanelShown
                        ? tabManager.windowThemeColor.opacity(0.35)
                        : .black.opacity(0.25),
                    radius: isCustomizePanelShown ? 8 : 5,
                    y: 2
                )
                
                .contentShape(Circle())
                .padding(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCustomizePanelShown ? "Close customize panel" : "Customize new tab page")
        .accessibilityIdentifier("browser.newTab.customizeButton")
        .accessibilityHint(isCustomizePanelShown ? "Closes the customize panel" : "Opens the customize panel")
        .help(isCustomizePanelShown ? "Close" : "Customize")
    }

    private var backgroundView: some View {
        ZStack {
            defaultBackgroundImage

            if let backgroundImageURL {
                CachedBackgroundImageView(url: backgroundImageURL)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var defaultBackgroundImage: some View {
        GeometryReader { geometry in
            Image("DefaultBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .ignoresSafeArea()
        }
    }

    private var backgroundImageURL: URL? {
        guard !tabManager.backgroundImageURL.isEmpty else { return nil }
        return URL(string: tabManager.backgroundImageURL)
    }

    private func open(_ bookmark: Bookmark, inNewTab: Bool) {
        guard let url = URL(string: bookmark.url) else { return }
        if inNewTab {
            tabManager.createTab(url: url, inBackground: true)
        } else {
            tabManager.activeTab?.load(url: url)
        }
    }
}

private enum NewTabLayout {
    static let tileWidth: CGFloat = 88
    static let iconSize: CGFloat = 47
    static let gridSpacing: CGFloat = 18
}

private struct NewTabBookmarkCard: View {
    let bookmark: Bookmark
    let accentColor: Color
    let onOpen: () -> Void
    let onOpenInNewTab: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void

    @State private var faviconImage: NSImage?
    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var editText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            if isRenaming {
                TextField("Edit bookmark title", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.22))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
                    .frame(maxWidth: NewTabLayout.tileWidth)
                    .onSubmit {
                        if !editText.isEmpty {
                            bookmark.title = editText
                            onRename(editText)
                            isRenaming = false
                        }
                    }
                    .onAppear {
                        NSApp.keyWindow?.makeFirstResponder(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.firstResponder)
                        }
                    }
            } else {
                Button(action: onOpen) {
                    VStack(spacing: 8) {
                        faviconTile
                            .frame(width: NewTabLayout.iconSize, height: NewTabLayout.iconSize)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)

                        Text(displayTitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.22))
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                    )
                            )
                            .frame(maxWidth: NewTabLayout.tileWidth)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: NewTabLayout.tileWidth)
                .opacity(isHovered ? 0.65 : 1)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .onHover { isHovered = $0 }
                .contextMenu {
                    Button("Open") { onOpen() }
                    Button("Open in New Tab") { onOpenInNewTab() }
                    Divider()
                    Button("Rename…") {
                        editText = bookmark.title
                        isRenaming = true
                    }
                    Button("Delete Bookmark", role: .destructive) { onDelete() }
                }
                .task(id: bookmark.url) {
                    await loadFavicon()
                }
                .accessibilityLabel(displayTitle)
                .accessibilityHint("Opens \(bookmark.url)")
                .help(bookmark.url)
            }
        }
    }

    @ViewBuilder
    private var faviconTile: some View {
        if let faviconImage {
            FaviconView(image: faviconImage, size: NewTabLayout.iconSize - 12)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.55))
                    .frame(width: NewTabLayout.iconSize - 12, height: NewTabLayout.iconSize - 12)
                Text(monogram)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var monogram: String {
        String(displayTitle.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    private var displayTitle: String {
        let title = bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? (URL(string: bookmark.url)?.host ?? bookmark.url) : title
    }

    private func loadFavicon() async {
        guard let pageURL = URL(string: bookmark.url),
              let scheme = pageURL.scheme?.lowercased(),
              (scheme == "http" || scheme == "https" || scheme == "webkit-extension"),
              let host = pageURL.host
        else { return }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/favicon.ico"
        guard let faviconURL = components.url else { return }

        faviconImage = await FaviconCache.shared.fetchImage(for: faviconURL)
    }

}
