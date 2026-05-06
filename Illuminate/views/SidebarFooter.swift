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
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(spacing: 12) {
            CavedDivider()
                .padding(.bottom, 2)

            HStack {
                LiquidGlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        if let activeTab, activeTab.hasPiPCandidate {
                            SidebarActionButton(
                                iconName: "rectangle.inset.filled",
                                themeColor: tabManager.windowThemeColor,
                                help: "Picture in Picture"
                            ) {
                                activeTab.togglePictureInPicture()
                            }
                        }

                        SidebarActionButton(
                            iconName: "gearshape.fill",
                            themeColor: tabManager.windowThemeColor,
                            help: "Settings"
                        ) {
                            tabManager.openSettingsTab()
                        }
                    }
                }

                Spacer()

                if let tab = activeTab {
                    LoadingIndicatorView(tab: tab)
                }

                SidebarActionButton(
                    iconName: downloadButtonIconName,
                    themeColor: tabManager.windowThemeColor,
                    symbolColor: downloadButtonColor,
                    help: "Downloads"
                ) {
                    downloadManager.acknowledgeRecentCompletedDownload()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        tabManager.toggleDownloadsSidebar()
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var downloadButtonIconName: String {
        (downloadManager.downloads.contains(where: \.isActive) || downloadManager.hasRecentCompletedDownload)
            ? "arrow.down.circle.fill"
            : "arrow.down.circle"
    }

    private var downloadButtonColor: Color? {
        if tabManager.sidebarPanel == .downloads {
            return tabManager.windowThemeColor
        }
        return downloadManager.hasRecentCompletedDownload ? .green : nil
    }
}

/// Reusable sidebar icon button with consistent hover styling.
private struct SidebarActionButton: View {
    let iconName: String
    let themeColor: Color
    var symbolColor: Color? = nil
    var help: String = ""
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(resolvedSymbolColor)
                .frame(width: 28, height: 28)
                .modifier(SidebarActionButtonBackground(isHovered: isHovered, themeColor: themeColor))
                .animation(.easeInOut(duration: 0.14), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .hoverCursor(.pointingHand)
        .help(help)
    }

    private var resolvedSymbolColor: Color {
        if let symbolColor {
            return symbolColor
        }
        return isHovered ? Color.textPrimary : Color.textSecondary
    }
}

private struct SidebarActionButtonBackground: ViewModifier {
    let isHovered: Bool
    let themeColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background {
                Circle().fill(.regularMaterial)
                Circle().fill(themeColor.opacity(isHovered ? 0.18 : 0.10))
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
