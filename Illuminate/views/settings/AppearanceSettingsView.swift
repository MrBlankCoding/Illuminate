//
//  AppearanceSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct AppearanceSettingsView: View {
    @EnvironmentObject private var tabManager: TabManager

    private var accentHexLabel: String {
        "#\(tabManager.windowThemeColor.toHex() ?? "89BBFF")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsShared.panelSection {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        ForEach(TabManager.UIStyle.allCases, id: \.rawValue) { style in
                            themeCard(style)
                        }
                    }

                    Divider().opacity(0.22)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Accent tones")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(accentHexLabel)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(tabManager.windowThemeColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(tabManager.windowThemeColor.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        HStack(alignment: .top, spacing: 30) {
                            VStack(alignment: .leading, spacing: 14) {
                                if !tabManager.backgroundImagePalette.isEmpty {
                                    colorRow(title: "From background", colors: tabManager.backgroundImagePalette)
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Custom Color")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)

                                customColorPicker
                            }
                        }
                    }
                }
            }

            SettingsShared.panelSection {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .leading) {
                            SettingsShared.glassBox(cornerRadius: 16)

                            HStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundStyle(Color.textSecondary)
                                TextField("Paste an image URL or pick a local file", text: $tabManager.backgroundImageURL)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 14)
                        }
                        .frame(height: 48)

                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.allowsMultipleSelection = false
                            panel.allowedContentTypes = [.image]

                            if panel.runModal() == .OK, let url = panel.url {
                                tabManager.backgroundImageURL = url.absoluteString
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles.tv")
                                Text("Browse")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(SettingsShared.glassBox(cornerRadius: 16, tint: tabManager.windowThemeColor))
                        }
                        .buttonStyle(.plain)
                        .hoverCursor(.pointingHand)
                    }

                    SettingsShared.infoRow(title: "Show image behind sidebar") {
                        Toggle("", isOn: $tabManager.showBackgroundBehindSidebar)
                            .labelsHidden()
                            .toggleStyle(GlassToggleStyle(tint: tabManager.windowThemeColor))
                            .hoverCursor(.pointingHand)
                    }
                }
            }
        }
    }

    private func themeCard(_ style: TabManager.UIStyle) -> some View {
        let active = tabManager.userInterfaceStyle == style

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                tabManager.userInterfaceStyle = style
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(themePreviewFill(for: style))
                        .frame(height: 92)
                        .overlay {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(style == .dark ? 0.14 : 0.62))
                                    .frame(height: 12)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 12)

                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(style == .dark ? 0.12 : 0.56))
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(style == .dark ? 0.08 : 0.42))
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                            }
                        }

                    if active {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(style.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                SettingsShared.glassBox(cornerRadius: 22, tint: active ? tabManager.windowThemeColor : nil)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(active ? tabManager.windowThemeColor.opacity(0.85) : Color.primary.opacity(0.07), lineWidth: active ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private func themePreviewFill(for style: TabManager.UIStyle) -> LinearGradient {
        switch style {
        case .dark:
            return LinearGradient(
                colors: [Color.black.opacity(0.95), Color.gray.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            return LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .system:
            return LinearGradient(
                colors: [Color.gray.opacity(0.78), Color.white.opacity(0.95), Color.black.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func colorRow(title: String, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        colorSwatch(color)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func colorSwatch(_ color: Color) -> some View {
        let active = tabManager.windowThemeColor == color

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                tabManager.windowThemeColor = color
            }
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(active ? 0.95 : 0.35), lineWidth: active ? 2 : 1)
                    )
                    .shadow(color: color.opacity(active ? 0.45 : 0.18), radius: active ? 10 : 5)

                if active {
                    Text("Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                } else {
                    Text(" ")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(SettingsShared.glassBox(cornerRadius: 18, tint: active ? color : nil))
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private var customColorPicker: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tabManager.windowThemeColor)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                )

            ColorPicker("Choose Color", selection: $tabManager.windowThemeColor, supportsOpacity: false)
                .labelsHidden()

            Text("Choose Color")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 220, alignment: .leading)
        .background(SettingsShared.glassBox(cornerRadius: 16, tint: tabManager.windowThemeColor.opacity(0.14)))
    }
}
