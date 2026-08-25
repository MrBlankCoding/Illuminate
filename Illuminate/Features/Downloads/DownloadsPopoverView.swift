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
    @EnvironmentObject private var environment: ProfileEnvironment
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPopoverPresented = false
    @State private var isHovered = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        if !downloadManager.downloads.isEmpty || isVisibleForUITesting {
            button
        }
    }

    private var isVisibleForUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestingForceDownloadsButton")
    }

    private var button: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: downloadManager.hasActiveDownloads ? "arrow.down.circle.fill" : "arrow.down.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isPopoverPresented ? tabManager.windowThemeColor : (isHovered ? Color.textPrimary : Color.textSecondary))
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
        }
        .buttonStyle(ToolbarIconPressStyle())
        .onHover { hovering in isHovered = hovering }
        .hoverCursor(.pointingHand)
        .help("Downloads")
        .accessibilityLabel("Downloads")
        .accessibilityIdentifier("browser.toolbar.downloadsButton")
        .accessibilityHint("Opens downloads popover")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            DownloadsPopoverContent()
                .environmentObject(tabManager)
                .environmentObject(environment)
                .frame(width: 340)
                .macPopover(cornerRadius: MacDesign.Radius.large)
        }
    }
}

private struct DownloadsPopoverContent: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @ObservedObject private var downloadManager = DownloadManager.shared

    private var items: [DownloadHistoryItem] {
        downloadManager.downloads.map { DownloadHistoryItem(task: $0) }
    }

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
                        clearFinished()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            CavedDivider()

            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 6) {
                        LazyVStack(spacing: 6) {
                            ForEach(items) { item in
                                DownloadEntryRow(
                                    item: item,
                                    store: environment.downloadHistoryStore,
                                    accentColor: tabManager.windowThemeColor,
                                    style: .popover
                                )
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: MacDesign.Radius.medium))
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 400)
            }
        }
        .accessibilityIdentifier("browser.downloads.popover")
    }

    private func clearFinished() {
        downloadManager.clearFinishedDownloads()
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
        .accessibilityIdentifier("browser.downloads.popover.emptyState")
    }
}

