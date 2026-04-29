//
//  SettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var tabSelectionAnimation
    @Namespace private var glassNamespace
    @State private var selectedTab: SettingsTab = .appearance

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundDecor

                HStack(spacing: 24) {
                    sidebarRail
                        .frame(width: min(max(geometry.size.width * 0.24, 230), 280))

                    mainContent
                }
                .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.windowBase)
            .accessibilityIdentifier("settings.root")
        }
    }

    private var backgroundDecor: some View {
        ZStack {
            LinearGradient(
                colors: [
                    tabManager.windowThemeColor.opacity(0.18),
                    theme.windowBase,
                    theme.windowBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tabManager.windowThemeColor.opacity(0.16))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: -260, y: -240)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 260, y: 220)
        }
        .ignoresSafeArea()
    }

    private var sidebarRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            profileCard
            navigationCard
            Spacer(minLength: 0)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tabManager.windowThemeColor.opacity(0.95),
                                    tabManager.windowThemeColor.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: environment.profile.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.profile.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(cornerRadius: 24)
    }

    private var navigationCard: some View {
        VStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                tabRailButton(tab)
            }
        }
        .padding(16)
        .glassBackground(cornerRadius: 24)
    }

    private func tabRailButton(_ tab: SettingsTab) -> some View {
        let active = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(active ? Color.white.opacity(0.16) : Color.clear)

                    Image(systemName: tab.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? .white : Color.textSecondary)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? .white : Color.textPrimary)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if active {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.clear)
                            .matchedGeometryEffect(id: "settings-tab-selection", in: tabSelectionAnimation)
                            .accentGlassPanel(accent: tabManager.windowThemeColor, cornerRadius: 18)
                            .modifier(GlassEffectIDModifier(id: "settings-tab-selection", namespace: glassNamespace))
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.clear)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
        .accessibilityIdentifier("settings.tab.\(tab.title.lowercased())")
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                activeTabContent
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .appearance:
            AppearanceSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .passwords:
            PasswordsSettingsView()
        case .cookies:
            CookiesSettingsView()
        case .downloads:
            DownloadsSettingsView()
        case .additional:
            ProtectionSettingsView()
        }
    }
}
