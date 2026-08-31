//
//  NewTabBookmarkGrid.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//


import SwiftUI
import SwiftData

enum NewTabLayout {
    static let tileWidth: CGFloat = 92
    static let iconSize: CGFloat = 52
    static let gridSpacing: CGFloat = MacDesign.Spacing.grid
}

struct NewTabBookmarkGrid: View {
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Query(sort: \Bookmark.title) private var allBookmarks: [Bookmark]

    private var bookmarks: [Bookmark] {
        guard !environment.isGuestSession else { return [] }
        return allBookmarks.filter { $0.profileID == environment.profile.id }
    }

    var body: some View {
        if !environment.isGuestSession, !bookmarks.isEmpty {
            VStack(alignment: .leading, spacing: MacDesign.Spacing.regular) {
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
            }
            .frame(maxWidth: MacDesign.Size.newTabGridMax)
        }
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

struct NewTabBookmarkCard: View {
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
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, MacDesign.Radius.small)
                    .padding(.vertical, MacDesign.Spacing.tiny)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.28))
                            .overlay(
                                Capsule().stroke(accentColor.opacity(0.55), lineWidth: MacDesign.Spacing.hairlineThin)
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
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(isHovered ? 0.30 : 0.16), Color.white.opacity(0.02)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: MacDesign.Spacing.hairlineThin
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: MacDesign.Radius.card, style: .continuous)
                                    .stroke(isHovered ? accentColor.opacity(0.45) : .clear, lineWidth: MacDesign.Spacing.hairlineThin)
                            }
                            .shadow(color: .black.opacity(isHovered ? 0.28 : 0.18), radius: isHovered ? MacDesign.Spacing.regular : MacDesign.Spacing.small, y: isHovered ? MacDesign.Spacing.small : MacDesign.Spacing.micro)
                            .scaleEffect(isHovered ? 1.06 : 1)
                            .offset(y: isHovered ? -1 : 0)

                        Text(displayTitle)
                            .font(.webSmallRegular)
                            .foregroundStyle(.white.opacity(isHovered ? 0.95 : 0.8))
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
                .animation(MacDesign.springAnimation, value: isHovered)
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
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.75), accentColor.blended(with: .black, fraction: 0.25).opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: MacDesign.Spacing.hairlineThin)
                    }
                    .frame(width: NewTabLayout.iconSize - MacDesign.Spacing.regular, height: NewTabLayout.iconSize - MacDesign.Spacing.regular)
                Text(monogram)
                    .font(.webMonogram)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: MacDesign.Spacing.micro, y: MacDesign.Spacing.hairline)
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
        let image = await FaviconLoader.shared.loadFavicon(from: faviconURL)
        faviconImage = image
    }
}