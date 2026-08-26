//
//  DownloadsSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

struct DownloadsSettingsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        Form {
            Section("Downloads") {
                Toggle("Reveal finished downloads in Finder", isOn: Binding(
                    get: { downloadManager.preferences.revealInFinderWhenFinished },
                    set: { downloadManager.setRevealInFinderWhenFinished($0) }
                ))
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.downloads.revealToggle")

                Toggle("Ask where to save each file", isOn: Binding(
                    get: { downloadManager.preferences.askWhereToSave },
                    set: { downloadManager.setAskWhereToSave($0) }
                ))
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.downloads.askWhereToSave")
            }

            Section("Save Location") {
                LabeledContent("Default folder") {
                    Text(downloadManager.downloadDirectoryURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Choose Folder...") {
                        chooseDownloadFolder()
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.downloads.chooseFolder")

                    Button("Use Default") {
                        downloadManager.resetDownloadDirectory()
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.downloads.resetFolder")
                }
            }
        }
        .settingsForm()
    }

    private func chooseDownloadFolder() {
        if let url = FilePanels.chooseDirectory(initialDirectory: downloadManager.downloadDirectoryURL) {
            downloadManager.setDownloadDirectory(url)
        }
    }
}
