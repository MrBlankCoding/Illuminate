//
//  DownloadEntryRow.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DownloadHistoryItem: Identifiable {
    let id: UUID
    let liveTask: DownloadTask?
    let filename: String
    let sourceURL: URL?
    let destinationURL: URL?
    let state: DownloadState
    let createdAt: Date
    let bytesWritten: Int64
    let totalBytesExpected: Int64?
    let errorDescription: String?
    let resumeData: Data?
    let resumeRequiresWebKit: Bool

    init(record: DownloadRecord) {
        self.id = record.id
        self.liveTask = nil
        self.filename = record.filename
        self.sourceURL = record.sourceURL
        self.destinationURL = record.destinationURL
        self.state = DownloadState(rawValue: record.stateRawValue) ?? .completed
        self.createdAt = record.createdAt
        self.bytesWritten = record.bytesWritten
        self.totalBytesExpected = record.totalBytesExpected
        self.errorDescription = record.errorDescription
        self.resumeData = record.resumeData
        self.resumeRequiresWebKit = record.resumeRequiresWebKit
    }

    init(record: DownloadRecord?, liveTask: DownloadTask?) {
        if let liveTask {
            self.init(task: liveTask)
            return
        }
        if let record {
            self.init(record: record)
            return
        }
        fatalError("DownloadHistoryItem requires a record or a task")
    }

    init(task: DownloadTask) {
        self.id = task.id
        self.liveTask = task
        self.filename = task.filename
        self.sourceURL = task.url
        self.destinationURL = task.destinationURL
        self.state = task.state
        self.createdAt = task.createdAt
        self.bytesWritten = task.bytesWritten
        self.totalBytesExpected = task.totalBytesExpected
        self.errorDescription = task.errorDescription
        self.resumeData = task.resumeData
        self.resumeRequiresWebKit = task.resumeRequiresWebKit
    }

    var isActive: Bool { state == .preparing || state == .downloading }
    var isCompleted: Bool { state == .completed }
    var canResume: Bool { state == .failed && resumeData != nil }

    var progress: Double {
        liveTask?.progress ?? 1
    }

    var fileExistsOnDisk: Bool {
        guard let path = destinationURL?.path else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}

struct DownloadEntryRow: View {
    enum Style {
        case popover
        case page
    }

    let item: DownloadHistoryItem
    let store: DownloadHistoryStore?
    let accentColor: Color
    var style: Style = .page

    init(
        item: DownloadHistoryItem,
        store: DownloadHistoryStore?,
        accentColor: Color,
        style: Style = .page
    ) {
        self.item = item
        self.store = store
        self.accentColor = accentColor
        self.style = style
        _fileExistsOnDisk = State(initialValue: item.fileExistsOnDisk)
    }

    private var downloadManager = DownloadManager.shared
    @State private var isHovering = false
    @State private var fileExistsOnDisk = false

    private var isCompact: Bool { style == .popover }
    private var isMissingFromDisk: Bool {
        item.isCompleted && !fileExistsOnDisk
    }

    private var isRowInteractive: Bool {
        item.isCompleted && fileExistsOnDisk
    }

    var body: some View {
        Group {
            if isCompact {
                content
            } else {
                InternalPageRow { content }
            }
        }
    }

    private var content: some View {
        HStack(spacing: isCompact ? MacDesign.Spacing.medium : MacDesign.Spacing.toolbarPadding) {
            fileIcon

            VStack(alignment: .leading, spacing: isCompact ? MacDesign.Spacing.tiny : MacDesign.Spacing.small) {
                HStack(spacing: MacDesign.Spacing.control) {
                    Text(item.filename)
                        .font(isCompact ? .webMicroMedium : .webBody.weight(.medium))
                        .foregroundStyle(.primary)
                        .strikethrough(isMissingFromDisk, color: .secondary)
                        .lineLimit(1)
                        .help(fullPath ?? item.filename)

                    Spacer(minLength: 0)

                    if let stateBadge {
                        stateBadge
                    }

                    removeButton
                }

                HStack(spacing: MacDesign.Spacing.control) {
                    Text(subtitleText)
                        .font(isCompact ? .webSmall : .webSmallRegular)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(isCompact ? .tail : .middle)

                    Spacer(minLength: 0)

                    if item.isActive {
                        cancelButton
                    } else if item.state == .failed {
                        if item.canResume {
                            resumeButton
                        } else {
                            retryButton
                        }
                    } else if isRowInteractive {
                        revealHint
                    }
                }

                if item.isActive {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .tint(accentColor)
                        .padding(.top, MacDesign.Spacing.micro)
                }
            }
        }
        .padding(.horizontal, isRowInteractive ? MacDesign.Spacing.tight : 0)
        .padding(.vertical, isRowInteractive ? MacDesign.Spacing.small : 0)
        .background(
            RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                .fill(Color.primary.opacity(isHovering && isRowInteractive ? 0.05 : 0))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            revealInFinder()
        }
        .onHover { hovering in
            guard isRowInteractive else { return }
            isHovering = hovering
        }
        .hoverCursor(isRowInteractive ? .pointingHand : .arrow)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .task(id: item.destinationURL) {
            fileExistsOnDisk = item.fileExistsOnDisk
        }
        .onDrag {
            guard isRowInteractive, let url = item.destinationURL else {
                return NSItemProvider()
            }
            // Finder/Desktop drag — fileURL provider so Finder accepts drop
            let provider = NSItemProvider(object: url as NSURL)
            provider.suggestedName = url.lastPathComponent
            return provider
        } preview: {
            // Glass-styled drag preview matching native Safari/ Finder feel
            HStack(spacing: 8) {
                Image(nsImage: resolvedIcon)
                    .resizable().scaledToFit()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.filename).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    if let host = item.sourceURL?.host {
                        Text(host).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: 180, alignment: .leading)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .frame(width: 240)
        }
    }

    private func revealInFinder() {
        guard let destinationURL = item.destinationURL, item.isCompleted else { return }
        FinderReveal.reveal(destinationURL)
    }

    private func removeEntry() {
        if item.isActive {
            downloadManager.cancelDownload(id: item.id)
        }
        downloadManager.removeFromSession(id: item.id)
        store?.remove(id: item.id)
    }

    private var fullPath: String? {
        item.destinationURL?.path
    }

    private var fileIcon: some View {
        Image(nsImage: resolvedIcon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: isCompact ? MacDesign.Size.iconButton : 36, height: isCompact ? MacDesign.Size.iconButton : 36)
            .opacity(isMissingFromDisk ? 0.35 : 1)
    }

    private var resolvedIcon: NSImage {
        if let dest = item.destinationURL, item.fileExistsOnDisk {
            return NSWorkspace.shared.icon(forFile: dest.path)
        }
        let ext = (item.filename as NSString).pathExtension
        if !ext.isEmpty, let uti = UTType(filenameExtension: ext) {
            return NSWorkspace.shared.icon(for: uti)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    private var subtitleText: String {
        switch item.state {
        case .completed:
            if isCompact {
                if isMissingFromDisk { return "File missing" }
                return item.destinationURL?
                    .deletingLastPathComponent()
                    .lastPathComponent ?? "Completed"
            }
            if let path = item.destinationURL?.path {
                return isMissingFromDisk ? "File missing · \(path)" : path
            }
            return "Completed"
        case .failed:
            return item.errorDescription ?? "Download failed"
        default:
            return statusDescription
        }
    }

    private var statusDescription: String {
        switch item.state {
        case .preparing:
            return "Preparing"
        case .downloading:
            if let total = item.totalBytesExpected, total > 0 {
                let written = ByteCountFormatter.string(fromByteCount: item.bytesWritten, countStyle: .file)
                let expected = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
                return "\(written) of \(expected)"
            }
            if item.bytesWritten > 0 {
                return ByteCountFormatter.string(fromByteCount: item.bytesWritten, countStyle: .file)
            }
            return "Starting"
        default:
            return ""
        }
    }

    private var stateBadge: AnyView? {
        switch item.state {
        case .preparing, .downloading, .cancelled:
            return AnyView(badgeText)
        case .completed:
            return isMissingFromDisk ? AnyView(badgeText) : nil
        case .failed:
            return nil
        }
    }

    private var badgeText: some View {
        Text(badgeLabel)
            .font(isCompact ? .webTinyBold.weight(.bold) : .webSmallBold)
            .foregroundStyle(badgeTint)
            .padding(.horizontal, isCompact ? MacDesign.Spacing.tight : MacDesign.Spacing.control)
            .padding(.vertical, isCompact ? MacDesign.Spacing.tiny : MacDesign.Spacing.small)
            .background(badgeTint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var badgeLabel: String {
        switch item.state {
        case .preparing:   return "Preparing"
        case .downloading: return "Downloading"
        case .completed:   return "File Missing"
        case .failed:      return "Failed"
        case .cancelled:   return "Cancelled"
        }
    }

    private var badgeTint: Color {
        switch item.state {
        case .preparing, .downloading: return accentColor
        case .completed:               return .secondary
        case .failed, .cancelled:      return .red
        }
    }

    private var cancelButton: some View {
        Button("Cancel") {
            downloadManager.cancelDownload(id: item.id)
        }
        .buttonStyle(InternalPageChipButtonStyle(color: .red))
    }

    private var retryButton: some View {
        Button("Retry") {
            downloadManager.retryDownload(item: item)
        }
        .buttonStyle(InternalPageChipButtonStyle(color: accentColor))
    }

    private var resumeButton: some View {
        Button("Resume") {
            downloadManager.resumeDownload(item: item)
        }
        .buttonStyle(InternalPageChipButtonStyle(color: accentColor))
    }

    private var revealHint: some View {
        Image(systemName: "chevron.right")
            .font(isCompact ? .webTinyBold.weight(.semibold) : .webSmallBold.weight(.semibold))
            .foregroundStyle(.tertiary)
            .opacity(isHovering ? 0.9 : 0.4)
    }

    private var removeButton: some View {
        Button {
            removeEntry()
        } label: {
            Image(systemName: "xmark")
                .font(isCompact ? .webTinyBold.weight(.bold) : .webSmallBold.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: isCompact ? 18 : 20, height: isCompact ? 18 : 20)
                .background(Color.primary.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
        .accessibilityLabel("Remove from history")
        .help("Remove from history")
    }
}