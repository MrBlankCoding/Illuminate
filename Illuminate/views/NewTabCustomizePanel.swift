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
    private static let contentWidth: CGFloat = 228
    private static let subtleAnimation: Animation = .easeOut(duration: 0.15)

    private static let quickAccents: [Color] = [
        Color(hex: "89BBFF"),   // default blue
        Color(hex: "A8D8A8"),   // sage green
        Color(hex: "FFB347"),   // amber
        Color(hex: "FF7F7F"),   // coral
        Color(hex: "C9A0DC"),   // lavender
        Color(hex: "7EC8E3"),   // sky
        Color(hex: "FFD700"),   // gold
        Color(hex: "F4A261"),   // peach
    ]

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
                    sidebarSection(title: "Theme") {
                        Picker("Theme", selection: $tabManager.userInterfaceStyle) {
                            ForEach(TabManager.UIStyle.allCases, id: \.rawValue) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    sidebarSection(title: "Accent Color") {
                        VStack(alignment: .leading, spacing: 12) {
                            swatchGrid(combinedSwatches)
                            HStack(spacing: 8) {
                                ColorPicker(
                                    "Accent",
                                    selection: $tabManager.windowThemeColor,
                                    supportsOpacity: false
                                )
                                .labelsHidden()
                                .frame(width: 28, height: 28)

                                Text("#\(tabManager.windowThemeColor.toHex() ?? "89BBFF")")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 10)
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
    private func swatchGrid(_ colors: [Color]) -> some View {
        let columns = Array(repeating: GridItem(.fixed(24), spacing: 8), count: 7)
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(colors, id: \.self) { color in
                let isSelected = tabManager.windowThemeColor == color
                Button {
                    withAnimation(Self.subtleAnimation) {
                        tabManager.windowThemeColor = color
                    }
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.white.opacity(0.9) : Color.primary.opacity(0.12),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }
                        .shadow(color: isSelected ? color.opacity(0.35) : .clear, radius: 2)
                        .scaleEffect(isSelected ? 1.05 : 1)
                        .animation(Self.subtleAnimation, value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set accent color")
            }
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

    private var combinedSwatches: [Color] {
        var result = Self.quickAccents
        for c in tabManager.backgroundImagePalette where !result.contains(c) {
            result.append(c)
        }
        return Array(result.prefix(14)) // max 2 rows of 7
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.message = "Choose an image for your new tab page background"
        panel.prompt = "Set Background"

        if panel.runModal() == .OK, let url = panel.url {
            tabManager.backgroundImageURL = url.absoluteString
        }
    }
}