//
//  TopBarView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI

struct TopBarView: View {
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
        LiquidGlassGroup(spacing: 12) {
        HStack(spacing: 16) {
            Group {
                if let activeTab = tabManager.activeTab {
                    NavigationControls(tab: activeTab, themeColor: tabManager.windowThemeColor)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").opacity(0.2)
                        Image(systemName: "chevron.right").opacity(0.2)
                        Image(systemName: "arrow.clockwise").opacity(0.2)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlassCapsule(tint: tabManager.windowThemeColor, padding: 0)
                }
            }
            .fixedSize()
            
            Spacer(minLength: 0)
            
            URLBar(
                activeTab: tabManager.activeTab,
                addressText: $addressBarText,
                themeColor: tabManager.windowThemeColor,
                onNavigate: onNavigate
            )
            .frame(maxWidth: 700)
            .layoutPriority(1)
            
            Spacer(minLength: 0)
            
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
                        Label("Add Profile...", systemImage: "plus.circle")
                    }
                }
            } label: {
                Image(systemName: profileEnvironment.profile.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .modifier(ProfileIconGlassModifier(theme: theme, tint: tabManager.windowThemeColor))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.leading, tabManager.showSidebar ? 16 : 80)
        .padding(.trailing, 20)
        .padding(.vertical, 6)
        }
        .background(
            ZStack {
                TopBarBackground(theme: theme)
                    .ignoresSafeArea(edges: .top)
            }
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.borderSubtle),
            alignment: .bottom
        )
        .background(DraggableArea())
    }
}

private struct ProfileIconGlassModifier: ViewModifier {
    let theme: BrowserTheme
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(tint.opacity(0.10))
                        .interactive(),
                    in: Circle()
                )
        } else {
            content
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
                )
        }
    }
}

private struct TopBarBackground: View {
    let theme: BrowserTheme

    var body: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(in: Rectangle())
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }
}
