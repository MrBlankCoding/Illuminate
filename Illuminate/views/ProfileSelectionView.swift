//
//  ProfileSelectionView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct ProfileSelectionView: View {
    @Binding var route: BrowserWindowRoute?
    var isStandalone: Bool = false
    @EnvironmentObject private var profileManager: ProfileManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var hoveredProfileID: UUID?
    @State private var showingAddProfile = false
    @State private var showingManage = false

    private let profileAccentColors: [Color] = [
        Color(hex: "5E7BFF"),
        Color(hex: "2DA7A1"),
        Color(hex: "F3A43B"),
        Color(hex: "E86F67"),
        Color(hex: "8A6CFF"),
        Color(hex: "4A90E2"),
        Color(hex: "69B578"),
        Color(hex: "D96ACF"),
    ]

    private var theme: BrowserTheme {
        BrowserTheme(accent: .accentBeam, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.windowBase
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Choose a profile for Illuminate")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityIdentifier("profileSelection.title")
                }
                .padding(.bottom, 36)

                // ui stuff
                profileGrid
                Spacer()
                bottomActions
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingAddProfile) {
            AddProfileSheet(isPresented: $showingAddProfile) { name, icon in
                let profile = profileManager.createProfile(named: name, iconName: icon)
                handleSelection(.profile(profile.id))
            }
            .environmentObject(profileManager)
            .accessibilityIdentifier("profileSelection.addProfileSheet")
        }
        .onAppear {
            registerDockMenuRoutes()
            checkAutoRedirect()
        }
        .onChange(of: profileManager.profiles) { oldValue, newValue in
            checkAutoRedirect()
        }
    }
    
    private func handleSelection(_ selection: BrowserWindowRoute) {
        if isStandalone {
            openWindow(value: selection)
            dismiss()
        } else {
            route = selection
        }
    }

    private func registerDockMenuRoutes() {
        DockMenuWindowRouter.shared.openProfileSelection = {
            openWindow(id: "profile-selection-window")
        }
        DockMenuWindowRouter.shared.openProfile = { profileID in
            openWindow(value: BrowserWindowRoute.profile(profileID))
        }
        DockMenuWindowRouter.shared.openGuest = {
            openWindow(value: BrowserWindowRoute.guest(UUID()))
        }
    }

    private func checkAutoRedirect() {
        guard route == nil, !showingManage, !showingAddProfile else { return }
        
        if profileManager.profiles.count == 1, let profile = profileManager.profiles.first {
            let visibleBrowserWindows = NSApp.windows.filter { window in
                window.isVisible && window.title != "Profile Selection" // Heuristic
            }
            
            if visibleBrowserWindows.isEmpty {
                handleSelection(.profile(profile.id))
            }
        }
    }

    private var profileGrid: some View {
        let columns = Array(
            repeating: GridItem(.fixed(120), spacing: 8),
            count: min(profileManager.profiles.count + 1, 4)
        )

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(profileManager.profiles.enumerated()), id: \.element.id) { index, profile in
                profileTile(profile: profile, index: index)
            }
        }
        .padding(.horizontal, 40)
    }

    private func profileTile(profile: BrowserProfile, index: Int) -> some View {
        let isHovered = hoveredProfileID == profile.id
        let avatarColor = profileAccentColors[index % profileAccentColors.count]
        let initials = profile.name.prefix(1).uppercased()

        return Button {
            handleSelection(.profile(profile.id))
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 76, height: 76)

                    if profile.iconName == "person.crop.circle" {
                        Text(initials)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: profile.iconName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                Text(profile.name)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 100)
            }
            .frame(width: 120, height: 128)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? theme.itemHover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isHovered ? Color.borderSubtle : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profileSelection.profileButton")
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            hoveredProfileID = hovering ? profile.id : nil
        }
        .hoverCursor(.pointingHand)
        .contextMenu {
            Button("Rename…") {
            }
            Divider()
            Button("Delete", role: .destructive) {
                profileManager.deleteProfile(profile)
            }
            .disabled(profileManager.profiles.count <= 1)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                showingAddProfile = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("Add profile")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .liquidGlassCapsule()
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .accessibilityIdentifier("profileSelection.addProfileButton")

            Button {
                handleSelection(.guest(UUID()))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 13, weight: .medium))
                    Text("Guest mode")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .liquidGlassCapsule()
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .accessibilityIdentifier("profileSelection.guestModeButton")
        }
    }
}

struct AddProfileSheet: View {
    @Binding var isPresented: Bool
    let onCreate: (String, String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var name = ""
    @State private var selectedIcon = "person.crop.circle"

    private let icons = [
        "person.crop.circle", "star.fill", "gamecontroller.fill",
        "briefcase.fill", "moon.stars.fill", "sparkles",
        "heart.fill", "leaf.fill", "flame.fill"
    ]

    private let previewColors: [Color] = [
        Color(hex: "5E7BFF"),
        Color(hex: "2DA7A1"),
        Color(hex: "F3A43B"),
        Color(hex: "8A6CFF"),
    ]
    @State private var selectedColorIndex = 0

    private var theme: BrowserTheme {
        BrowserTheme(accent: previewColors[selectedColorIndex], colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .padding(8)
                        .glassBackground(cornerRadius: 999)
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ZStack {
                Circle()
                    .fill(previewColors[selectedColorIndex])
                    .frame(width: 80, height: 80)
                Image(systemName: selectedIcon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)

            HStack(spacing: 10) {
                ForEach(previewColors.indices, id: \.self) { i in
                    Circle()
                        .fill(previewColors[i])
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(theme.windowBase, lineWidth: selectedColorIndex == i ? 2 : 0)
                                .padding(1)
                        )
                        .overlay(
                            Circle()
                                .stroke(previewColors[i], lineWidth: selectedColorIndex == i ? 3 : 0)
                        )
                        .onTapGesture { selectedColorIndex = i }
                        .hoverCursor(.pointingHand)
                }
            }
            .padding(.bottom, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 5), spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(selectedIcon == icon
                                        ? previewColors[selectedColorIndex]
                                        : Color.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(selectedIcon == icon ? theme.itemHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture { selectedIcon = icon }
                        .hoverCursor(.pointingHand)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Profile name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.bottom, 6)
                    .accessibilityIdentifier("profileSelection.addProfileNameField")

                Rectangle()
                    .fill(name.isEmpty
                          ? Color.borderSubtle
                          : previewColors[selectedColorIndex])
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.15), value: name.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(previewColors[selectedColorIndex])
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .accessibilityIdentifier("profileSelection.cancelAddProfileButton")

                Button("Add") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onCreate(name, selectedIcon)
                    isPresented = false
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(name.trimmingCharacters(in: .whitespaces).isEmpty
                              ? Color.secondary.opacity(0.3)
                              : previewColors[selectedColorIndex])
                )
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("profileSelection.confirmAddProfileButton")
            }
            .padding(.bottom, 24)
        }
        .frame(width: 320)
        .glassBackground(cornerRadius: 24)
    }
}
