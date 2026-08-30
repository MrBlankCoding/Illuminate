//
//  DownloadsPopoverView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct DownloadsToolbarButton: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    private var downloadManager = DownloadManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPopoverPresented = false
    @State private var isHovered = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
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
                .font(.webBody.weight(.semibold))
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
                .environment(tabManager)
                .environment(environment)
                .frame(width: 340)
                .macPopover(cornerRadius: MacDesign.Radius.large)
        }
    }
}

private struct DownloadsPopoverContent: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    private var downloadManager = DownloadManager.shared

    private var items: [DownloadHistoryItem] {
        downloadManager.downloads.map { DownloadHistoryItem(task: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Downloads")
                    .font(.webCaptionBold)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if !downloadManager.downloads.isEmpty {
                    Button("Clear Finished") {
                        clearFinished()
                    }
                    .buttonStyle(.plain)
                    .font(.webSmallRegular.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, MacDesign.Spacing.roomy)
            .padding(.vertical, MacDesign.Spacing.toolbarPadding)

            CappedDivider()

            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: MacDesign.Spacing.tight) {
                        LazyVStack(spacing: MacDesign.Spacing.tight) {
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
                    .padding(MacDesign.Spacing.regular)
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
        InternalPageEmptyState(
            icon: "arrow.down.circle",
            message: "No Downloads",
            subtitle: "Files you download will appear here.",
            verticalPadding: MacDesign.Spacing.pageHeaderPadding
        )
        .accessibilityIdentifier("browser.downloads.popover.emptyState")
    }
}

