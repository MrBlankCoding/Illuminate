//
//  DownloadsTabView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/19/26.
//

import SwiftUI

struct DownloadsTabView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: MacDesign.Spacing.section) {
            SettingsShared.panelSection {
                VStack(alignment: .leading, spacing: MacDesign.Spacing.grid) {
                    SettingsShared.infoRow(title: "Reveal finished downloads in Finder") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { downloadManager.preferences.revealInFinderWhenFinished },
                                set: { downloadManager.setRevealInFinderWhenFinished($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(GlassToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                        .accessibilityIdentifier("settings.downloads.revealToggle")
                    }

                    SettingsShared.infoRow(title: "Ask where to save each file") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { downloadManager.preferences.askWhereToSave },
                                set: { downloadManager.setAskWhereToSave($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(GlassToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                        .accessibilityIdentifier("settings.downloads.askWhereToSave")
                    }

                    SettingsShared.infoRow(title: "Default save location") {
                        HStack(spacing: MacDesign.Spacing.medium) {
                            Text(downloadManager.downloadDirectoryURL.path)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button("Choose Folder") {
                                if let url = FilePanels.chooseDirectory(initialDirectory: downloadManager.downloadDirectoryURL) {
                                    downloadManager.setDownloadDirectory(url)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tabManager.windowThemeColor)
                            .accessibilityIdentifier("settings.downloads.chooseFolder")

                            Button("Reset") {
                                downloadManager.resetDownloadDirectory()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityIdentifier("settings.downloads.resetFolder")
                        }
                    }
                }
            }
        }
    }
}
