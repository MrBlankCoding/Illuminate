//
//  DownloadsPopoverView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct DownloadsToolbarButton: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPopoverPresented = false
    @State private var isHovered = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        Button {
            downloadManager.acknowledgeRecentCompletedDownload()
            isPopoverPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: downloadIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(downloadIconColor)
                    .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
                    .background {
                        Circle()
                            .fill(
                                isPopoverPresented
                                    ? tabManager.windowThemeColor.opacity(0.18)
                                    : (isHovered ? theme.itemHover : Color.clear)
                            )
                    }
                    .animation(MacDesign.fastAnimation, value: isHovered)

                if downloadManager.downloads.contains(where: \.isActive) {
                    Circle()
                        .fill(tabManager.windowThemeColor)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .hoverCursor(.pointingHand)
        .help("Downloads")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            DownloadsPopoverContent()
                .environmentObject(tabManager)
                .frame(width: 340)
                .macPopover(cornerRadius: MacDesign.Radius.large)
        }
    }

    private var downloadIconName: String {
        downloadManager.downloads.contains(where: \.isActive)
            ? "arrow.down.circle.fill"
            : "arrow.down.circle"
    }

    private var downloadIconColor: Color {
        if isPopoverPresented {
            return tabManager.windowThemeColor
        }
        if downloadManager.hasRecentCompletedDownload {
            return .green
        }
        return isHovered ? Color.textPrimary : Color.textSecondary
    }
}

private struct DownloadsPopoverContent: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Downloads")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if !downloadManager.downloads.isEmpty {
                    Button("Clear Finished") {
                        downloadManager.clearFinishedDownloads()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            CavedDivider()

            if downloadManager.downloads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 6) {
                        LazyVStack(spacing: 6) {
                            ForEach(downloadManager.downloads) { task in
                                DownloadRowView(task: task, themeColor: tabManager.windowThemeColor)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 400)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 32))
                .foregroundStyle(Color.textSecondary.opacity(0.5))

            Text("No Downloads")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("Files you download will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
    }
}

private struct DownloadRowView: View {
    let task: DownloadTask
    let themeColor: Color

    var body: some View {
        HStack(spacing: 10) {
            fileIcon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.filename)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    actionButton
                }

                HStack(spacing: 6) {
                    Text(secondaryText)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    statusBadge
                }

                if task.isActive {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                        .tint(themeColor)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: MacDesign.Radius.medium))
        .background(
            RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous)
                .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        if task.state == .completed, task.destinationURL != nil {
            Button("Show") {
                DownloadManager.shared.revealDownload(task)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(themeColor)
        } else if task.isActive {
            Button("Cancel") {
                DownloadManager.shared.cancelDownload(id: task.id)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.red)
        }
    }

    private var statusBadge: some View {
        Text(stateLabel)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(statusTint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusTint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var stateLabel: String {
        switch task.state {
        case .preparing:   return "Preparing"
        case .downloading: return "Downloading"
        case .completed:   return "Complete"
        case .failed:      return "Failed"
        case .cancelled:   return "Cancelled"
        }
    }

    private var secondaryText: String {
        switch task.state {
        case .completed:
            return task.destinationURL?
                .deletingLastPathComponent()
                .lastPathComponent ?? "Completed"
        default:
            return task.statusDescription
        }
    }

    private var statusTint: Color {
        switch task.state {
        case .completed:            return .green
        case .failed, .cancelled:   return .red
        case .preparing, .downloading: return themeColor
        }
    }

    private var fileIcon: some View {
        Image(nsImage: resolvedFileIcon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 28, height: 28)
    }

    private var resolvedFileIcon: NSImage {
        if let dest = task.destinationURL {
            return NSWorkspace.shared.icon(forFile: dest.path)
        }
        let ext = (task.filename as NSString).pathExtension
        if let uti = UTType(filenameExtension: ext), !ext.isEmpty {
            return NSWorkspace.shared.icon(for: uti)
        }
        return NSWorkspace.shared.icon(for: .data)
    }
}
