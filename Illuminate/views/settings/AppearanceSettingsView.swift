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
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $tabManager.userInterfaceStyle) {
                    ForEach(TabManager.UIStyle.allCases, id: \.rawValue) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Accent color") {
                    HStack(spacing: 10) {
                        Text(accentHexLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                        ColorPicker("Accent color", selection: $tabManager.windowThemeColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }

            Section("Bookmark Bar") {
                Picker("Show Bookmark Bar", selection: $tabManager.bookmarkBarVisibility) {
                    ForEach(BookmarkBarVisibility.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            if !tabManager.backgroundImagePalette.isEmpty {
                Section("Suggested Colors") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(tabManager.backgroundImagePalette, id: \.self) { color in
                                Button {
                                    tabManager.windowThemeColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            Circle()
                                                .strokeBorder(
                                                    tabManager.windowThemeColor == color ? color : Color.primary.opacity(0.12),
                                                    lineWidth: tabManager.windowThemeColor == color ? 3 : 1
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Use suggested accent color")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Start Page Background") {
                LabeledContent("Image") {
                    TextField("Image URL or local file path", text: $tabManager.backgroundImageURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 280)
                }

                HStack(spacing: 8) {
                    Button("Choose Image...") {
                        chooseBackgroundImage()
                    }
                    .controlSize(.small)

                    Button("Clear") {
                        tabManager.backgroundImageURL = ""
                    }
                    .controlSize(.small)
                    .disabled(tabManager.backgroundImageURL.isEmpty)
                }


            }
        }
        .settingsForm()
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK, let url = panel.url {
            tabManager.backgroundImageURL = url.absoluteString
        }
    }
}
