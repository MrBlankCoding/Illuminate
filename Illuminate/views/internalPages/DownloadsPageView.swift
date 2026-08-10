//
//  DownloadsPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct DownloadsPageView: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        InternalPage(
            icon: "arrow.down.circle.fill",
            title: "Downloads",
            accentColor: tabManager.windowThemeColor
        ) {
            if downloadManager.downloads.isEmpty {
                InternalPageEmptyState(
                    icon: "arrow.down.circle",
                    message: "Files you download will appear here."
                )
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("\(downloadManager.downloads.count) item\(downloadManager.downloads.count == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        Spacer()

                        let hasFinished = downloadManager.downloads.contains { !$0.isActive }
                        if hasFinished {
                            Button("Clear Finished") {
                                downloadManager.clearFinishedDownloads()
                            }
                            .buttonStyle(InternalPageChipButtonStyle(color: tabManager.windowThemeColor))
                        }
                    }

                    VStack(spacing: 6) {
                        ForEach(downloadManager.downloads) { task in
                            DownloadsPageRow(task: task, accentColor: tabManager.windowThemeColor)
                        }
                    }
                }
            }
        }
    }
}


private struct DownloadsPageRow: View {
    let task: DownloadTask
    let accentColor: Color

    var body: some View {
        InternalPageRow {
            HStack(spacing: 14) {
                fileIcon

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(task.filename)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        stateBadge
                    }

                    HStack(spacing: 8) {
                        Text(subtitleText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        actionButton
                    }

                    if task.isActive {
                        ProgressView(value: task.progress)
                            .progressViewStyle(.linear)
                            .tint(accentColor)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var fileIcon: some View {
        Image(nsImage: resolvedIcon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 36, height: 36)
    }

    private var resolvedIcon: NSImage {
        if let dest = task.destinationURL {
            return NSWorkspace.shared.icon(forFile: dest.path)
        }
        let ext = (task.filename as NSString).pathExtension
        if !ext.isEmpty, let uti = UTType(filenameExtension: ext) {
            return NSWorkspace.shared.icon(for: uti)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    private var subtitleText: String {
        switch task.state {
        case .completed:
            return task.destinationURL?
                .deletingLastPathComponent()
                .lastPathComponent ?? "Completed"
        default:
            return task.statusDescription
        }
    }

    private var stateBadge: some View {
        Text(badgeLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(badgeTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeTint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var badgeLabel: String {
        switch task.state {
        case .preparing:   return "Preparing"
        case .downloading: return "Downloading"
        case .completed:   return "Complete"
        case .failed:      return "Failed"
        case .cancelled:   return "Cancelled"
        }
    }

    private var badgeTint: Color {
        switch task.state {
        case .completed:               return .green
        case .failed, .cancelled:      return .red
        case .preparing, .downloading: return accentColor
        }
    }


    @ViewBuilder
    private var actionButton: some View {
        if task.state == .completed, task.destinationURL != nil {
            Button("Show in Finder") {
                DownloadManager.shared.revealDownload(task)
            }
            .buttonStyle(InternalPageChipButtonStyle(color: accentColor))
        } else if task.isActive {
            Button("Cancel") {
                DownloadManager.shared.cancelDownload(id: task.id)
            }
            .buttonStyle(InternalPageChipButtonStyle(color: .red))
        }
    }
}
