//
//  NewTabView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftData
import SwiftUI

struct NewTabView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.title) private var allBookmarks: [Bookmark]
    @State private var isCustomizePanelShown = false
    @State private var hasAppeared = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    private var bookmarks: [Bookmark] {
        guard !environment.isGuestSession else { return [] }
        return allBookmarks.filter { $0.profileID == environment.profile.id }
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: MacDesign.Size.toolbarRowHeight) {
                        Spacer(minLength: MacDesign.Spacing.largeSpacer)
                        header
                        bookmarkGrid
                        Spacer(minLength: MacDesign.Spacing.largeSpacer)
                    }
                    .frame(maxWidth: .infinity, minHeight: 480)
                    .padding(.horizontal, MacDesign.Spacing.pageHeaderPadding)
                }
                .scrollIndicators(.hidden)

                customizeButton
                    .padding(.trailing, MacDesign.Spacing.section)
                    .padding(.bottom, MacDesign.Spacing.section)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isCustomizePanelShown {
                NewTabCustomizePanel()
                    .environment(tabManager)
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
        VStack(spacing: MacDesign.Spacing.control) {
            // should change the font or remove entierly
            Text("Illuminate")
                .font(.webHero)
                .tracking(1)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.32), radius: MacDesign.Spacing.medium, y: MacDesign.Spacing.micro)
                .shadow(color: .black.opacity(0.18), radius: MacDesign.Spacing.micro, y: MacDesign.Spacing.hairline)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : MacDesign.Spacing.tight)
    }

    @ViewBuilder
    private var bookmarkGrid: some View {
        if !environment.isGuestSession {
            Group {
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
                .frame(maxWidth: MacDesign.Size.newTabGridMax)
            }
        }
    }

    private var customizeButton: some View {
        Button {
            withAnimation(MacDesign.springAnimation) {
                isCustomizePanelShown.toggle()
            }
        } label: {
            Image(systemName: isCustomizePanelShown ? "xmark" : "pencil")
                .font(.webCaptionBold)
                .frame(width: MacDesign.Size.floatingButton, height: MacDesign.Size.floatingButton)
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
                            lineWidth: MacDesign.Spacing.hairlineThin
                        )
                }
                .shadow(
                    color: isCustomizePanelShown
                        ? tabManager.windowThemeColor.opacity(0.35)
                        : .black.opacity(0.25),
                    radius: isCustomizePanelShown ? MacDesign.Spacing.control : MacDesign.Spacing.mini,
                    y: MacDesign.Spacing.micro
                )

                .contentShape(Circle())
                .padding(MacDesign.Spacing.small)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCustomizePanelShown ? "Close customize panel" : "Customize new tab page")
        .accessibilityIdentifier("browser.newTab.customizeButton")
        .accessibilityHint(isCustomizePanelShown ? "Closes the customize panel" : "Opens the customize panel")
        .help(isCustomizePanelShown ? "Close" : "Customize")
    }

    private var backgroundView: some View {
        ZStack {
            if backgroundImageURL == nil {
                tabManager.windowThemeColor
                    .ignoresSafeArea()
            }

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
    static let gridSpacing: CGFloat = MacDesign.Spacing.grid
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
        VStack(spacing: MacDesign.Spacing.control) {
            if isRenaming {
                TextField("Edit bookmark title", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.webSmallRegular)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, MacDesign.Radius.small)
                    .padding(.vertical, MacDesign.Spacing.tiny)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.22))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin)
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
                    VStack(spacing: MacDesign.Spacing.control) {
                        faviconTile
                            .frame(width: NewTabLayout.iconSize, height: NewTabLayout.iconSize)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: MacDesign.Radius.card))
                            .overlay {
                                RoundedRectangle(cornerRadius: MacDesign.Radius.card, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: MacDesign.Spacing.hairlineThin)
                            }
                            .shadow(color: .black.opacity(0.18), radius: MacDesign.Spacing.small, y: MacDesign.Spacing.micro)

                        Text(displayTitle)
                            .font(.webSmallRegular)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, MacDesign.Radius.small)
                            .padding(.vertical, MacDesign.Spacing.tiny)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.22))
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin)
                                    )
                            )
                            .frame(maxWidth: NewTabLayout.tileWidth)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: NewTabLayout.tileWidth)
                .opacity(isHovered ? 0.65 : 1)
                .animation(MacDesign.fastAnimation, value: isHovered)
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
            FaviconView(image: faviconImage, size: NewTabLayout.iconSize - MacDesign.Spacing.regular)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous)
                    .fill(accentColor.opacity(0.55))
                    .frame(width: NewTabLayout.iconSize - MacDesign.Spacing.regular, height: NewTabLayout.iconSize - MacDesign.Spacing.regular)
                Text(monogram)
                    .font(.webMonogram)
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

        // Uses Nuke pipeline via FaviconLoader; falls back to legacy cache on failure.
        if let image = await FaviconLoader.shared.loadFavicon(from: faviconURL) {
            faviconImage = image
        } else {
            faviconImage = await FaviconCache.shared.fetchImage(for: faviconURL)
        }
    }

}
