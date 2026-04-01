//
//  SettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Password.url) private var allPasswords: [Password]
    @State private var selectedTab = 0
    @State private var isCloseHovered = false
    @State private var passwordSearchText = ""

    private var passwords: [Password] {
        return allPasswords.filter { $0.profileID == environment.profile.id }
    }

    var filteredPasswords: [Password] {
        if passwordSearchText.isEmpty {
            return passwords
        } else {
            return passwords.filter { $0.url.lowercased().contains(passwordSearchText.lowercased()) || $0.username.lowercased().contains(passwordSearchText.lowercased()) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            
            HStack(spacing: 32) {
                tabButton(title: "Appearance", index: 0)
                tabButton(title: "Shortcuts", index: 1)
                tabButton(title: "Passwords", index: 2)
                tabButton(title: "Cookies", index: 3)
                tabButton(title: "Additional", index: 4)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)

            ZStack {
                switch selectedTab {
                case 0:
                    ScrollView {
                        appearanceTab
                            .padding(.bottom, 40)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                case 1:
                    ScrollView {
                        shortcutsTab
                            .padding(.bottom, 40)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                case 2:
                    passwordsTab
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                case 3:
                    cookiesSettingsTab
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                case 4:
                    additionalTab
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                default:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.bgBase
                
                // Top accent glow
                EllipticalGradient(
                    gradient: Gradient(colors: [
                        tabManager.windowThemeColor.opacity(0.12),
                        tabManager.windowThemeColor.opacity(0.04),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.8
                )
                .ignoresSafeArea()
                
                // Bottom accent glow
                EllipticalGradient(
                    gradient: Gradient(colors: [
                        tabManager.windowThemeColor.opacity(0.08),
                        Color.clear
                    ]),
                    center: .bottomTrailing,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.6
                )
                .ignoresSafeArea()
            }
            .animation(.easeInOut(duration: 0.8), value: tabManager.windowThemeColor)
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.top, 48)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: selectedTab == index ? .semibold : .medium))
                    .foregroundStyle(selectedTab == index ? Color.textPrimary : Color.textSecondary)
                
                Capsule()
                    .fill(selectedTab == index ? tabManager.windowThemeColor : Color.clear)
                    .frame(width: 24, height: 4)
            }
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .kerning(1.2)
                .padding(.horizontal, 6)
            
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }


    private var appearanceTab: some View {
        VStack(spacing: 40) {
            // Theme Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("THEME")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .kerning(1.2)
                    .padding(.horizontal, 6)
                
                HStack(spacing: 20) {
                    themeCard(title: "Dark", style: .dark, icon: "moon.fill")
                    themeCard(title: "Light", style: .light, icon: "sun.max.fill")
                    themeCard(title: "System", style: .system, icon: "desktopcomputer")
                }
            }
            
            // Accent Color
            VStack(alignment: .leading, spacing: 16) {
                Text("ACCENT COLOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .kerning(1.2)
                    .padding(.horizontal, 6)
                
                VStack(spacing: 24) {
                    if !tabManager.backgroundImagePalette.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Extracted from background")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                            
                            HStack(spacing: 16) {
                                ForEach(tabManager.backgroundImagePalette, id: \.self) { color in
                                    PresetCircle(color: color, isSelected: tabManager.windowThemeColor == color) {
                                        withAnimation(.spring(response: 0.3)) {
                                            tabManager.windowThemeColor = color
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presets")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                        
                        let presets: [Color] = [
                            Color(red: 0.537, green: 0.733, blue: 1.0),
                            Color(red: 0.8, green: 0.6, blue: 0.9),
                            Color(red: 1.0, green: 0.6, blue: 0.6),
                            Color(red: 1.0, green: 0.8, blue: 0.5),
                            Color(red: 0.6, green: 0.9, blue: 0.7),
                            Color(red: 0.5, green: 0.5, blue: 0.5),
                            Color(red: 0.9, green: 0.4, blue: 0.7),
                            Color(red: 0.4, green: 0.8, blue: 0.9),
                            Color(red: 0.7, green: 0.9, blue: 0.4)
                        ]
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(presets, id: \.self) { color in
                                    PresetCircle(color: color, isSelected: tabManager.windowThemeColor == color) {
                                        withAnimation(.spring(response: 0.3)) {
                                            tabManager.windowThemeColor = color
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(20)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            
            // Background Image
            VStack(alignment: .leading, spacing: 16) {
                Text("CUSTOM BACKGROUND")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .kerning(1.2)
                    .padding(.horizontal, 6)
                
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        TextField("Enter Image URL...", text: $tabManager.backgroundImageURL)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(10)
                        
                        Button {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.canChooseFiles = true
                            panel.allowedContentTypes = [.image]
                            if panel.runModal() == .OK, let url = panel.url {
                                tabManager.backgroundImageURL = url.absoluteString
                            }
                        } label: {
                            Image(systemName: "photo")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .hoverCursor(.pointingHand)
                    }
                    
                    Toggle("Show image behind sidebar", isOn: $tabManager.showBackgroundBehindSidebar)
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .font(.system(size: 14))
                        .hoverCursor(.pointingHand)
                }
                .padding(20)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 48)
    }

    private func themeCard(title: String, style: TabManager.UIStyle, icon: String) -> some View {
        let isSelected = tabManager.userInterfaceStyle == style
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                tabManager.userInterfaceStyle = style
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style == .dark ? Color.black : (style == .light ? Color.white : Color.gray.opacity(0.3)))
                        .frame(height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(style == .dark ? .white : (style == .light ? .black : .primary))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? tabManager.windowThemeColor : Color.clear, lineWidth: 2)
                )
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isSelected ? tabManager.windowThemeColor.opacity(0.08) : Color.primary.opacity(0.03))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? tabManager.windowThemeColor.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private var passwordsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textSecondary)
                TextField("Search passwords...", text: $passwordSearchText)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(10)
            .padding(.horizontal, 48)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 12) {
                    if filteredPasswords.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 40)
                            Image(systemName: "lock.shield")
                                .font(.system(size: 48))
                                .foregroundStyle(tabManager.windowThemeColor.opacity(0.4))
                            Text("No passwords found")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                        }
                    } else {
                        ForEach(filteredPasswords) { password in
                            passwordRow(password)
                        }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 24)
            }
        }
    }

    private func passwordRow(_ password: Password) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(password.url)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(password.username)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(password.passwordData, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(tabManager.windowThemeColor)
                        .frame(width: 28, height: 28)
                        .background(tabManager.windowThemeColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .help("Copy Password")
                
                Button(role: .destructive) {
                    modelContext.delete(password)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .help("Delete")
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("KEYBOARD SHORTCUTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .kerning(1.2)
            
            VStack(spacing: 16) {
                shortcutRow(label: "New Tab", keys: "⌘ T")
                shortcutRow(label: "Close Tab", keys: "⌘ W")
                shortcutRow(label: "Reopen Closed Tab", keys: "⌘ ⇧ T")
                shortcutRow(label: "Bookmark Tab", keys: "⌘ B")
                shortcutRow(label: "Focus URL Bar", keys: "⌘ L")
                shortcutRow(label: "Refresh Page", keys: "⌘ R")
                shortcutRow(label: "Find in Page", keys: "⌘ F")
                shortcutRow(label: "Toggle Full Screen", keys: "⌘ ⇧ F")
                shortcutRow(label: "Toggle Sidebar", keys: "⌘ S")
                shortcutRow(label: "Zoom In", keys: "⌘ +")
                shortcutRow(label: "Zoom Out", keys: "⌘ -")
                shortcutRow(label: "Reset Zoom", keys: "⌘ 0")
                shortcutRow(label: "Go Back", keys: "⌘ ←")
                shortcutRow(label: "Go Forward", keys: "⌘ →")
                shortcutRow(label: "Developer Tools", keys: "⌘ ⇧ I")
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
    }

    private func shortcutRow(label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
            
            Spacer()
            
            Text(keys)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tabManager.windowThemeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tabManager.windowThemeColor.opacity(0.12))
                )
        }
        .padding(.vertical, 6)
    }

    private var cookiesSettingsTab: some View {
        VStack(spacing: 28) {
            settingsSection(title: "Cookie Management") {
                Toggle("Enable Cookies", isOn: Binding(
                    get: { environment.webKitManager.cookiesEnabled },
                    set: { environment.webKitManager.cookiesEnabled = $0 }
                ))
                .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                .font(.system(size: 14))
                .hoverCursor(.pointingHand)
                
                Text("Turning off cookies is a bad idea...")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
            
            settingsSection(title: "Privacy") {
                Button(role: .destructive) {
                    CookieViewModel().clearAllCookies(with: environment.webKitManager)
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Cookies & Data")
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.red)
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
    }

    private var additionalTab: some View {
        VStack(spacing: 28) {
            settingsSection(title: "Content Blocking") {
                Toggle("Enable Ad Blocker", isOn: Binding(
                    get: { environment.adBlockService.isEnabled },
                    set: { environment.adBlockService.isEnabled = $0 }
                ))
                .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                .font(.system(size: 14))
                .hoverCursor(.pointingHand)
                
                Text("Block ads... Because who likes ads?")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
    }

}

private struct PresetCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0.35), lineWidth: isSelected ? 2.5 : 1)
                )
                .overlay(
                    Circle()
                        .strokeBorder(color.opacity(0.35), lineWidth: 6)
                        .scaleEffect(1.35)
                        .opacity(isSelected ? 1 : 0)
                )
                .shadow(color: color.opacity(isSelected ? 0.45 : 0.2), radius: isSelected ? 10 : 5)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Theme preset")
    }
}
