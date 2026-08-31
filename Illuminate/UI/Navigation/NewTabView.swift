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
    @State private var isEaselSidebarVisible = true
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
            if isEaselSidebarVisible {
                easelSidebar
                    .frame(width: 280)
                    .background(.ultraThinMaterial)
                    .overlay(Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 0.5), alignment: .trailing)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

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

                HStack {
                    easelSidebarToggleButton
                        .padding(.leading, MacDesign.Spacing.section)
                    Spacer()
                    customizeButton
                        .padding(.trailing, MacDesign.Spacing.section)
                }
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

    private var easelSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Easels", systemImage: "paintbrush.pointed.fill")
                    .font(.webCaptionBold)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(MacDesign.springAnimation) { isEaselSidebarVisible = false }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("Hide Easels")
                Button {
                    let easel = environment.easelManager.createEasel()
                    tabManager.createTab(url: easel.url)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("New Easel (⇧⌘E)")
                .accessibilityIdentifier("browser.newTab.newEasel.sidebar")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().opacity(0.12)

            if environment.easelManager.easels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "paintbrush.pointed.fill").font(.system(size: 24, weight: .light)).foregroundStyle(.white.opacity(0.6))
                    Text("No easels yet").font(.webSmall).foregroundStyle(.white.opacity(0.7))
                    Text("Create your first whiteboard").font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(environment.easelManager.easels) { easel in
                            EaselSidebarCard(easel: easel)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(maxHeight: .infinity)
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

    private var easelSidebarToggleButton: some View {
        Button {
            withAnimation(MacDesign.springAnimation) {
                isEaselSidebarVisible.toggle()
            }
        } label: {
            Image(systemName: isEaselSidebarVisible ? "sidebar.leading" : "paintbrush.pointed.fill")
                .font(.webCaptionBold)
                .frame(width: MacDesign.Size.floatingButton, height: MacDesign.Size.floatingButton)
                .background(
                    isEaselSidebarVisible
                        ? AnyShapeStyle(.ultraThinMaterial)
                        : AnyShapeStyle(tabManager.windowThemeColor.opacity(0.85)),
                    in: Circle()
                )
                .foregroundStyle(isEaselSidebarVisible ? .white.opacity(0.9) : .white)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: MacDesign.Spacing.hairlineThin)
                }
                .shadow(color: .black.opacity(0.25), radius: MacDesign.Spacing.mini, y: MacDesign.Spacing.micro)
                .contentShape(Circle())
                .padding(MacDesign.Spacing.small)
        }
        .buttonStyle(.plain)
        .help(isEaselSidebarVisible ? "Hide Easels" : "Show Easels")
        .accessibilityLabel(isEaselSidebarVisible ? "Hide Easels Sidebar" : "Show Easels Sidebar")
        .accessibilityIdentifier("browser.newTab.easelSidebarToggle")
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
        // error
        let image = await FaviconLoader.shared.loadFavicon(from: faviconURL)
        faviconImage = image
    }

}

private struct EaselSidebarCard: View {
    let easel: Easel
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @State private var isHovered = false

    var body: some View {
        Button {
            tabManager.createTab(url: easel.url)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    if let preview = environment.easelManager.previewImage(for: easel.id) {
                        Image(nsImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05))
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(easel.title).font(.webSmall.weight(.semibold)).lineLimit(1).foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(isHovered ? 0.14 : 0.08), radius: isHovered ? 6 : 4, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1 : 0.96)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { tabManager.createTab(url: easel.url) }
            Button("Rename…") {
                // Quick rename via prompt — uses simple alert
                let alert = NSAlert()
                alert.messageText = "Rename Easel"
                alert.informativeText = "Enter new title:"
                let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
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
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.red.opacity(0.9), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .help("Open \(easel.title)")
    }
}
