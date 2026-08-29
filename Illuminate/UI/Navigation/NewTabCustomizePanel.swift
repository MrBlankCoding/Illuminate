//
//  NewTabCustomizePanel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct NewTabCustomizePanel: View {
    @EnvironmentObject private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showThemeEditor = false
    private static let contentWidth: CGFloat = 228
    private static let subtleAnimation: Animation = .easeOut(duration: 0.15)

    private var backgroundLabel: String {
        guard !tabManager.backgroundImageURL.isEmpty,
              let url = URL(string: tabManager.backgroundImageURL)
        else { return "None" }
        let name = url.lastPathComponent
        return name.isEmpty ? "Custom URL" : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Customize", systemImage: "paintbrush.pointed.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tabManager.windowThemeColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()
                .frame(maxWidth: .infinity)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    sidebarSection(title: "Appearance") {
                        VStack(alignment: .leading, spacing: 12) {
                            if tabManager.backgroundImageURL.isEmpty {
                                Button {
                                    showThemeEditor = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(tabManager.windowThemeColor)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                            }
                                        
                                        Text("Advanced Editor")
                                            .font(.system(size: 12, weight: .medium))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .liquidGlassCapsule()
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showThemeEditor, arrowEdge: .leading) {
                                    ThemeEditorView(theme: $tabManager.theme)
                                        .frame(width: 378, height: 512)
                                }
                            } else {
                                Text("Auto-determined from image")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }

                    sidebarSection(title: "Background Image") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                backgroundThumbnail

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backgroundLabel)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Text(
                                        tabManager.backgroundImageURL.isEmpty
                                            ? "No image set"
                                            : tabManager.backgroundImageURL
                                    )
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 8) {
                                Button {
                                    chooseBackgroundImage()
                                } label: {
                                    Label("Choose…", systemImage: "folder")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .liquidGlassCapsule()
                                }
                                .buttonStyle(.plain)

                                if !tabManager.backgroundImageURL.isEmpty {
                                    Button {
                                        withAnimation(Self.subtleAnimation) {
                                            tabManager.backgroundImageURL = ""
                                        }
                                    } label: {
                                        Label("Remove", systemImage: "xmark")
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .liquidGlassCapsule(tint: .red)
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                .frame(width: Self.contentWidth, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }

            .frame(maxWidth: .infinity)
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier("browser.newTab.customizePanel")
        .glassEffect(.regular, in: .rect)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 0.5)
        }
    }

    @ViewBuilder
    private func sidebarSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            content()
        }
    }

    @ViewBuilder
    private var backgroundThumbnail: some View {
        let size: CGFloat = 52
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary)

            if !tabManager.backgroundImageURL.isEmpty,
               let url = URL(string: tabManager.backgroundImageURL) {
                CachedBackgroundImageView(url: url)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
        }
    }

    private func chooseBackgroundImage() {
        let urls = FilePanels.chooseFiles(
            allowedContentTypes: [.image],
            message: "Choose an image for your new tab page background",
            prompt: "Set Background"
        )
        if let url = urls.first {
            tabManager.backgroundImageURL = url.absoluteString
        }
    }
}