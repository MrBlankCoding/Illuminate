//
//  SidebarFooter.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct SidebarFooter: View {
    var activeTab: Tab?
    @EnvironmentObject private var tabManager: TabManager
    @State private var showingDownloads = false
    @State private var isSettingsHovered = false
    @State private var isDownloadsHovered = false
    @State private var isPiPHovered = false
    @State private var hasVisibleDownloads = DownloadManager.shared.hasVisibleDownloads

    var body: some View {
        VStack(spacing: 12) {
            CavedDivider()
                .padding(.bottom, 2)

            HStack {
                HStack(spacing: 8) {
                    if let activeTab, activeTab.hasPiPCandidate {
                        Button {
                            activeTab.togglePictureInPicture()
                        } label: {
                            Image(systemName: "rectangle.inset.filled")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isPiPHovered ? Color.textPrimary : Color.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(isPiPHovered ? tabManager.windowThemeColor.opacity(0.18) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(isPiPHovered ? Color.borderGlass : Color.clear, lineWidth: 1)
                                )
                                .animation(.easeInOut(duration: 0.14), value: isPiPHovered)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isPiPHovered = hovering
                        }
                        .hoverCursor(.pointingHand)
                    }

                    Button {
                        tabManager.openSettingsTab()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSettingsHovered ? Color.textPrimary : Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isSettingsHovered ? tabManager.windowThemeColor.opacity(0.18) : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(isSettingsHovered ? Color.borderGlass : Color.clear, lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.14), value: isSettingsHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isSettingsHovered = hovering
                    }
                    .hoverCursor(.pointingHand)

                    if hasVisibleDownloads {
                        Button {
                            showingDownloads = true
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isDownloadsHovered ? Color.textPrimary : Color.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(isDownloadsHovered ? tabManager.windowThemeColor.opacity(0.18) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(isDownloadsHovered ? Color.borderGlass : Color.clear, lineWidth: 1)
                                )
                                .animation(.easeInOut(duration: 0.14), value: isDownloadsHovered)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isDownloadsHovered = hovering
                        }
                        .hoverCursor(.pointingHand)
                        .popover(isPresented: $showingDownloads, arrowEdge: .top) {
                            DownloadsView()
                                .environmentObject(tabManager)
                        }
                    }
                }

                Spacer()

                if let tab = activeTab {
                    LoadingIndicatorView(tab: tab)
                }
            }
            .padding(.horizontal, 2)
        }
        .onReceive(NotificationCenter.default.publisher(for: DownloadManager.downloadsDidChangeNotification)) { notification in
            if let hasVisibleDownloads = notification.userInfo?["hasVisibleDownloads"] as? Bool {
                self.hasVisibleDownloads = hasVisibleDownloads
            }
        }
    }
}

private struct LoadingIndicatorView: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject var tab: Tab

    var body: some View {
        if tab.isLoading {
            ProgressView()
                .controlSize(.small)
                .tint(tabManager.windowThemeColor)
        }
    }
}
