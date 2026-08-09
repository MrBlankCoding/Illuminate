//
//  BrowserToolbarView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

private enum ToolbarMetrics {
    static let tabRowHeight: CGFloat = 42
    static let toolbarHeight: CGFloat = 48
    static let trafficLightWidth: CGFloat = 78
    static let trailingPad: CGFloat = 14
    static let toolbarLeadingPad: CGFloat = 14
}

struct BrowserToolbarView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var profileEnvironment: ProfileEnvironment
    @EnvironmentObject private var profileManager: ProfileManager
    @Environment(\.colorScheme) private var colorScheme

    @Binding var addressBarText: String
    let onNavigate: () -> Void

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStripRow
            separatorLine
            navigationRow
        }
        .background(toolbarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)
        }

        .background(DraggableArea())
    }

    private var tabStripRow: some View {
        HStack(spacing: 0) {
            if !tabManager.isFullScreen {
                Spacer()
                    .frame(width: ToolbarMetrics.trafficLightWidth)
            } else {
                Spacer()
                    .frame(width: 8)
            }

            TabBarView()
                .frame(maxWidth: .infinity)

            Spacer()
                .frame(width: ToolbarMetrics.trailingPad - 8)
        }
        .frame(height: ToolbarMetrics.tabRowHeight)
    }

    private var separatorLine: some View {
        Rectangle()
            .fill(theme.separator.opacity(0.45))
            .frame(height: 0.5)
    }

    private var navigationRow: some View {
        HStack(spacing: 6) {
            Spacer()
                .frame(width: ToolbarMetrics.toolbarLeadingPad)
            navigationControls
            URLBar(
                activeTab: tabManager.activeTab,
                addressText: $addressBarText,
                themeColor: tabManager.windowThemeColor,
                onNavigate: onNavigate
            )
            .frame(maxWidth: .infinity)   // fills everything between nav and right buttons
            .layoutPriority(1)

            // Downloads popover button
            DownloadsToolbarButton()

            // Profile switcher
            profileMenu

            // Trailing padding
            Spacer()
                .frame(width: ToolbarMetrics.trailingPad)
        }
        .frame(height: ToolbarMetrics.toolbarHeight)
    }

    @ViewBuilder
    private var navigationControls: some View {
        if let activeTab = tabManager.activeTab {
            NavigationControls(tab: activeTab, themeColor: tabManager.windowThemeColor)
        } else {
            HStack(spacing: 2) {
                inertNavIcon("chevron.left")
                inertNavIcon("chevron.right")
                inertNavIcon("arrow.clockwise")
            }
        }
    }

    private func inertNavIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.textSecondary.opacity(0.28))
            .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
    }

    private var profileMenu: some View {
        Menu {
            Section("Switch Profile") {
                ForEach(profileManager.profiles) { profile in
                    Button {
                        DockMenuWindowRouter.shared.openProfile?(profile.id)
                    } label: {
                        Label(profile.name, systemImage: profile.iconName)
                    }
                    .disabled(profile.id == profileEnvironment.profile.id)
                }
            }

            Section {
                Button {
                    DockMenuWindowRouter.shared.openGuest?()
                } label: {
                    Label("Guest Profile", systemImage: "person.crop.circle.badge.questionmark")
                }
                Button {
                    DockMenuWindowRouter.shared.openProfileSelection?()
                } label: {
                    Label("Add Profile…", systemImage: "plus.circle")
                }
            }
        } label: {
            Image(systemName: profileEnvironment.profile.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 26, height: 26)
                .modifier(ProfileIconGlassModifier(tint: tabManager.windowThemeColor))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var toolbarBackground: some View {
        Rectangle()
            .fill(.bar)
            .background(theme.toolbarBase)
            .ignoresSafeArea(edges: .top)
    }
}

private struct ProfileIconGlassModifier: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: Circle())
            .background { Circle().fill(tint.opacity(0.08)) }
            .overlay {
                Circle().stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
    }
}
