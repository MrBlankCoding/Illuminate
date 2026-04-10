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
        HStack(spacing: 0) {
            if !tabManager.showSidebar {
                Spacer().frame(width: 80)
            } else {
                Spacer().frame(width: 16)
            }
            
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
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                URLBar(
                    activeTab: tabManager.activeTab,
                    addressText: $addressBarText,
                    themeColor: tabManager.windowThemeColor,
                    onNavigate: onNavigate
                )
                .frame(maxWidth: 600)
                
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
                        .background(
                            Circle()
                                .fill(theme.chromeMaterial)
                                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
                        )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            
            Spacer()
            
            if !tabManager.showSidebar {
                Spacer().frame(width: 20)
            } else {
                Spacer().frame(width: 20)
            }
        }
        .padding(.vertical, 6)
        .background(
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [theme.chromeFillTop, theme.chromeFillBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(theme.chromeMaterial)
                    .ignoresSafeArea(edges: .top)

                Rectangle()
                    .fill(theme.sidebarTint)
                    .ignoresSafeArea(edges: .top)
            }
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.chromeStroke),
            alignment: .bottom
        )
        .background(DraggableArea())
    }
}
