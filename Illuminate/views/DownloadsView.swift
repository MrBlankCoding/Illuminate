//
//  DownloadsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import QuickLookThumbnailing
import SwiftUI

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if downloadManager.downloads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(downloadManager.downloads) { task in
                            DownloadRow(task: task)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(width: 410, height: 480)
        .glassBackground()
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Downloads")
                    .font(.webH2)
                Text(downloadManager.preferences.safeDownloadsOnly ? "Protection is on" : "Protection is relaxed")
                    .font(.webMicro)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if !downloadManager.downloads.isEmpty {
                Button("Clear Finished") {
                    downloadManager.clearFinishedDownloads()
                }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.textSecondary)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.textSecondary.opacity(0.5))
            Text("No downloads yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text("Files you download will appear here.")
                .font(.webMicro)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DownloadRow: View {
    let task: DownloadTask
    @EnvironmentObject private var tabManager: TabManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                preview

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.filename)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        safetyBadge
                    }

                    if task.state != .completed {
                        Text(task.statusDescription)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(statusTint)
                            .lineLimit(2)
                    }

                    if task.isActive {
                        ProgressView(value: task.progress)
                            .progressViewStyle(.linear)
                            .tint(tabManager.windowThemeColor)
                    }
                }
            }

            HStack {
                if task.state == .completed {
                    Spacer()

                    Button("Show in Finder") {
                        DownloadManager.shared.revealDownload(task)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                } else {
                    Text(stateLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(statusTint.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    if task.isActive {
                    Button("Cancel") {
                        DownloadManager.shared.cancelDownload(id: task.id)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.red)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.bgSurface.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var preview: some View {
        if task.state == .completed, let destinationURL = task.destinationURL {
            DownloadPreview(url: destinationURL, fallbackSymbolName: fileIcon(for: task.filename), tint: iconTint)
        } else {
            Image(systemName: fileIcon(for: task.filename))
                .font(.system(size: 24))
                .foregroundStyle(iconTint)
                .frame(width: 64, height: 64)
                .background(iconTint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var stateLabel: String {
        switch task.state {
        case .preparing:
            return "Preparing"
        case .downloading:
            return "Downloading"
        case .completed:
            return "Complete"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        case .blocked:
            return "Blocked"
        }
    }

    private var statusTint: Color {
        switch task.state {
        case .completed:
            return .green
        case .failed, .blocked, .cancelled:
            return .red
        case .preparing, .downloading:
            return tabManager.windowThemeColor
        }
    }

    private var iconTint: Color {
        switch task.safetyLevel {
        case .safe:
            return tabManager.windowThemeColor
        case .caution:
            return .orange
        case .blocked:
            return .red
        }
    }

    @ViewBuilder
    private var safetyBadge: some View {
        if task.safetyLevel != .safe {
            Text(task.safetyLevel == .blocked ? "Blocked" : "Caution")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(task.safetyLevel == .blocked ? Color.red : Color.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((task.safetyLevel == .blocked ? Color.red : Color.orange).opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "zip", "gz", "rar":
            return "archivebox"
        case "dmg", "pkg", "app":
            return "exclamationmark.shield"
        case "jpg", "png", "gif", "webp":
            return "photo"
        case "mp4", "mov", "avi":
            return "video"
        case "mp3", "wav", "m4a":
            return "music.note"
        default:
            return "doc"
        }
    }
}

private struct DownloadPreview: View {
    let url: URL
    let fallbackSymbolName: String
    let tint: Color

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tint.opacity(0.12))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: url) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        if let directImage = NSImage(contentsOf: url) {
            await MainActor.run {
                image = directImage
            }
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 128, height: 128),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            await MainActor.run {
                image = thumbnail.nsImage
            }
        } catch {
            await MainActor.run {
                image = nil
            }
        }
    }
}
