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
    var prewarmProfile: (UUID) -> Void = { _ in }
    @Environment(ProfileManager.self) private var profileManager: ProfileManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var hoveredProfileID: UUID?
    @State private var showingAddProfile = false

    @State private var selectionWasExplicit = false
    @State private var didRouteLaunchWindow = false
    @State private var isRedirectingToProfile = false

    @State private var renamingProfile: BrowserProfile?
    @State private var renameText: String = ""

    @State private var profileToDelete: BrowserProfile?

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
        BrowserTheme(accent: .accentBeam, colorScheme: colorScheme, windowThemeColor: .accentBeam)
    }

    var body: some View {
        ZStack {
            theme.windowBase
                .ignoresSafeArea()

            if isAwaitingLaunchRoute {
                EmptyView()
            } else {
                profileSelectionContent
            }
        }
        .sheet(isPresented: $showingAddProfile) {
            AddProfileSheet(isPresented: $showingAddProfile) { name, icon in
                let profile = profileManager.createProfile(named: name, iconName: icon)
                handleSelection(.profile(profile.id))
            }
            .environment(profileManager)
            .accessibilityIdentifier("profileSelection.addProfileSheet")
        }
        .alert("Rename Profile", isPresented: renamingProfileBinding) {
            TextField("Profile name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingProfile = nil }
            Button("Rename") {
                if let profile = renamingProfile {
                    profileManager.renameProfile(profile, to: renameText)
                }
                renamingProfile = nil
            }
        } message: {
            Text("Enter a new name for this profile.")
        }
        .alert("Delete “\(profileToDelete?.name ?? "")”?", isPresented: profileToDeleteBinding) {
            Button("Cancel", role: .cancel) { profileToDelete = nil }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    profileManager.deleteProfile(profile)
                }
                profileToDelete = nil
            }
        } message: {
            Text("This permanently deletes this profile's history, passwords, and other browsing data. This can't be undone.")
        }
        .onAppear {
            registerDockMenuRoutes()
            selectionWasExplicit = DockMenuWindowRouter.shared.consumeExplicitProfileSelectionRequest()
            routeLaunchWindow()
            adoptSoleProfileIfNeeded()
            dismissIfRedundant()
        }
        .onChange(of: profileManager.profiles) { _, _ in
            routeLaunchWindow()
            adoptSoleProfileIfNeeded()
        }
    }

    private var isAwaitingLaunchRoute: Bool {
        isStandalone && !selectionWasExplicit && !profileManager.isRunningUITests
            && (!didRouteLaunchWindow || isRedirectingToProfile)
    }

    private var profileSelectionContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("Choose a profile for Illuminate")
                    .font(.system(size: 22, weight: .regular, design: .default))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityIdentifier("profileSelection.title")
            }
            .padding(.bottom, 36)

            profileGrid
            Spacer()
            bottomActions
                .padding(.bottom, 32)
        }
    }

    private func routeLaunchWindow() {
        guard isStandalone, !selectionWasExplicit, !profileManager.isRunningUITests,
              !didRouteLaunchWindow else { return }
        guard !profileManager.profiles.isEmpty else { return }

        didRouteLaunchWindow = true
        guard let profileID = profileManager.launchProfileID else { return }

        isRedirectingToProfile = true
        guard BrowserWindowRegistry.shared.beginOpening(for: profileID) else {
            DispatchQueue.main.async { [dismiss] in dismiss() }
            return
        }
        openWindow(value: BrowserWindowRoute.profile(profileID))
        dismiss()
    }

    private func adoptSoleProfileIfNeeded() {
        guard !isStandalone, route == nil, !showingAddProfile else { return }
        guard profileManager.profiles.count == 1, let profile = profileManager.profiles.first else { return }
        route = .profile(profile.id)
    }

    private var renamingProfileBinding: Binding<Bool> {
        Binding(
            get: { renamingProfile != nil },
            set: { isPresented in if !isPresented { renamingProfile = nil } }
        )
    }

    private var profileToDeleteBinding: Binding<Bool> {
        Binding(
            get: { profileToDelete != nil },
            set: { isPresented in if !isPresented { profileToDelete = nil } }
        )
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
            DockMenuWindowRouter.shared.requestProfileSelection {
                NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
            }
        }
        DockMenuWindowRouter.shared.openProfile = { profileID in
            openWindow(value: BrowserWindowRoute.profile(profileID))
        }
        DockMenuWindowRouter.shared.openGuest = {
            openWindow(value: BrowserWindowRoute.guest(UUID()))
        }
    }

    private func dismissIfRedundant() {
        guard isStandalone, !selectionWasExplicit, !profileManager.isRunningUITests,
              !isRedirectingToProfile else { return }
        guard BrowserWindowRegistry.shared.activeCount > 0 else { return }

        AppLog.ui("Dismissing redundant profile window; a browser window is already open.")
        DispatchQueue.main.async { [dismiss] in
            dismiss()
        }
    }

    private var profileGrid: some View {
        let tileWidth: CGFloat = 120
        let columns = Array(
            repeating: GridItem(.fixed(tileWidth), spacing: MacDesign.Spacing.control),
            count: min(max(profileManager.profiles.count, 1), 4)
        )

        return LazyVGrid(columns: columns, spacing: MacDesign.Spacing.control) {
            ForEach(Array(profileManager.profiles.enumerated()), id: \.element.id) { index, profile in
                profileTile(profile: profile, index: index)
            }
        }
        .padding(.horizontal, MacDesign.Spacing.page)
    }

    private func profileTile(profile: BrowserProfile, index: Int) -> some View {
        let isHovered = hoveredProfileID == profile.id
        let avatarColor = profileAccentColors[index % profileAccentColors.count]
        let initials = profile.name.prefix(1).uppercased()

        return Button {
            handleSelection(.profile(profile.id))
        } label: {
            VStack(spacing: MacDesign.Spacing.regular) {
                ZStack {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 76, height: 76)

                    if profile.iconName == ProfileManager.defaultIconName {
                        Text(initials)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textOnAccent)
                    } else {
                        Image(systemName: profile.iconName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(theme.textOnAccent)
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
            .macControlBackground(
                isActive: isHovered,
                tint: theme.accent,
                radius: MacDesign.Radius.medium
            )
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profileSelection.profileButton")
        .animation(MacDesign.fastAnimation, value: isHovered)
        .onHover { hovering in
            hoveredProfileID = hovering ? profile.id : nil
            if hovering {
                prewarmProfile(profile.id)
            }
        }
        .hoverCursor(.pointingHand)
        .contextMenu {
            Button("Rename…") {
                renameText = profile.name
                renamingProfile = profile
            }
            .accessibilityIdentifier("profileSelection.renameProfileButton")

            CavedDivider()

            Button("Delete", role: .destructive) {
                profileToDelete = profile
            }
            .disabled(profileManager.profiles.count <= 1)
            .accessibilityIdentifier("profileSelection.deleteProfileButton")
        }
    }

    private var bottomActions: some View {
        HStack(spacing: MacDesign.Spacing.regular) {
            Button {
                showingAddProfile = true
            } label: {
                HStack(spacing: MacDesign.Spacing.tight) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("Add profile")
                        .font(.system(size: 13, weight: .medium))
                }
                .font(.webBody)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, MacDesign.Spacing.section)
                .padding(.vertical, MacDesign.Spacing.control)
                .liquidGlassCapsule()
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .accessibilityIdentifier("profileSelection.addProfileButton")

            Button {
                handleSelection(.guest(UUID()))
            } label: {
                HStack(spacing: MacDesign.Spacing.tight) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 13, weight: .medium))
                    Text("Guest mode")
                        .font(.system(size: 13, weight: .medium))
                }
                .font(.webBody)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, MacDesign.Spacing.section)
                .padding(.vertical, MacDesign.Spacing.control)
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
    @State private var selectedIcon = ProfileManager.defaultIconName

    private let icons = [
        ProfileManager.defaultIconName, "star.fill", "gamecontroller.fill",
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
        BrowserTheme(accent: previewColors[selectedColorIndex], colorScheme: colorScheme, windowThemeColor: .accentBeam)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
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
                        .padding(MacDesign.Spacing.control)
                        .glassBackground(cornerRadius: 999)
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
            }
            .padding(.horizontal, MacDesign.Spacing.section)
            .padding(.top, MacDesign.Spacing.roomy)

            ZStack {
                Circle()
                    .fill(previewColors[selectedColorIndex])
                    .frame(width: 80, height: 80)
                Image(systemName: selectedIcon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent)
            }
            .padding(.top, MacDesign.Spacing.control)
            .padding(.bottom, MacDesign.Spacing.section)

            HStack(spacing: MacDesign.Spacing.control) {
                ForEach(previewColors.indices, id: \.self) { i in
                    Button {
                        selectedColorIndex = i
                    } label: {
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
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .hoverCursor(.pointingHand)
                    .accessibilityLabel("Profile color")
                }
            }
            .padding(.bottom, MacDesign.Spacing.section)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(MacDesign.Size.iconButton + 8)), count: 5), spacing: MacDesign.Spacing.control) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(selectedIcon == icon
                                            ? previewColors[selectedColorIndex]
                                            : Color.textSecondary)
                            .frame(width: MacDesign.Size.largeIconButton + 4, height: MacDesign.Size.largeIconButton + 4)
                            .macControlBackground(
                                isActive: selectedIcon == icon,
                                tint: previewColors[selectedColorIndex],
                                radius: MacDesign.Radius.small
                            )
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .hoverCursor(.pointingHand)
                    .accessibilityLabel("Profile icon")
                }
            }
            .padding(.horizontal, MacDesign.Spacing.section)
            .padding(.bottom, MacDesign.Spacing.section)

            VStack(alignment: .leading, spacing: MacDesign.Spacing.tight) {
                TextField("Profile name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.bottom, MacDesign.Spacing.tight)
                    .accessibilityIdentifier("profileSelection.addProfileNameField")

                Rectangle()
                    .fill(name.isEmpty
                          ? Color.borderSubtle
                          : previewColors[selectedColorIndex])
                    .frame(height: 2)
                    .animation(MacDesign.fastAnimation, value: name.isEmpty)
            }
            .padding(.horizontal, MacDesign.Spacing.section)
            .padding(.bottom, MacDesign.Spacing.section)

            HStack(spacing: MacDesign.Spacing.regular) {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(previewColors[selectedColorIndex])
                .padding(.horizontal, MacDesign.Spacing.section)
                .padding(.vertical, MacDesign.Spacing.control)
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .accessibilityIdentifier("profileSelection.cancelAddProfileButton")

                Button("Add") {
                    guard !trimmedName.isEmpty else { return }
                    onCreate(trimmedName, selectedIcon)
                    isPresented = false
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textOnAccent)
                .padding(.horizontal, MacDesign.Spacing.section)
                .padding(.vertical, MacDesign.Spacing.control)
                .background(
                    Capsule()
                        .fill(trimmedName.isEmpty
                              ? Color.secondary.opacity(0.3)
                              : previewColors[selectedColorIndex])
                )
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .disabled(trimmedName.isEmpty)
                .accessibilityIdentifier("profileSelection.confirmAddProfileButton")
            }
            .padding(.bottom, MacDesign.Spacing.section)
        }
        .frame(width: 320)
        .glassBackground(cornerRadius: MacDesign.Radius.panel)
    }
}