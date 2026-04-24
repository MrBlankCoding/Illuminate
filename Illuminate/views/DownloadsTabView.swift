//
//  DownloadsTabView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/19/26.
//

import SwiftUI

struct DownloadsTabView: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            panelSection {
                VStack(alignment: .leading, spacing: 18) {
                    infoRow(title: "Reveal finished downloads in Finder") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { downloadManager.preferences.revealInFinderWhenFinished },
                                set: { downloadManager.setRevealInFinderWhenFinished($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                        .accessibilityIdentifier("settings.downloads.revealToggle")
                    }

                    infoRow(title: "Ask where to save each file") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { downloadManager.preferences.askWhereToSave },
                                set: { downloadManager.setAskWhereToSave($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                        .accessibilityIdentifier("settings.downloads.askWhereToSave")
                    }

                    infoRow(title: "Default save location") {
                        HStack(spacing: 10) {
                            Text(downloadManager.downloadDirectoryURL.path)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button("Choose Folder") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.canCreateDirectories = true
                                panel.directoryURL = downloadManager.downloadDirectoryURL

                                if panel.runModal() == .OK, let url = panel.url {
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

    private func panelSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground(cornerRadius: 26))
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }

    private func infoRow(title: String, tint: Color? = nil, trailing: @escaping () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint ?? Color.textPrimary)

            Spacer()

            trailing()
        }
    }
}