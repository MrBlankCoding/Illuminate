//
//  ProfileSelectionView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/22/26.
//

import SwiftUI

struct ProfileSelectionView: View {
    @Binding var profileID: UUID?
    @EnvironmentObject private var profileManager: ProfileManager
    @State private var creatingProfile = false
    @State private var newProfileName = ""
    @State private var selectedIcon = "person.crop.circle"
    @State private var editingProfileID: UUID?
    @State private var editingProfileName = ""

    private let availableIcons = [
        "person.crop.circle", "star.fill", "gamecontroller.fill",
        "briefcase.fill", "moon.stars.fill", "sparkles",
        "heart.fill", "leaf.fill", "flame.fill"
    ]

    private let accentColors: [Color] = [
        Color(red: 0.22, green: 0.43, blue: 0.82),
        Color(red: 0.15, green: 0.62, blue: 0.66),
        Color(red: 0.91, green: 0.55, blue: 0.24)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.13),
                    Color(red: 0.08, green: 0.11, blue: 0.18),
                    Color(red: 0.13, green: 0.10, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("Choose a Profile")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("Each profile keeps its own tabs, cookies, site sessions, saved passwords, and browser settings.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 540)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 18)], spacing: 18) {
                    ForEach(Array(profileManager.profiles.enumerated()), id: \.element.id) { index, profile in
                        profileCard(for: profile, index: index)
                    }
                    createProfileCard
                }
                .frame(maxWidth: 720)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 48)
        }
    }

    private func profileCard(for profile: BrowserProfile, index: Int) -> some View {
        let accent = accentColors[index % accentColors.count]
        let isEditing = editingProfileID == profile.id

        return Button {
            guard !isEditing else { return }
            profileID = profile.id
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.95),
                                    accent.opacity(0.55),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 128)

                    iconPickerButton(
                        iconName: profile.iconName,
                        foreground: Color.white,
                        background: Color.white.opacity(0.14)
                    ) { icon in
                        profileManager.updateIcon(for: profile, iconName: icon)
                    }
                    .padding(18)

                    HStack {
                        Spacer()
                        Menu {
                            Button("Rename") {
                                editingProfileID = profile.id
                                editingProfileName = profile.name
                            }

                            Button("Delete", role: .destructive) {
                                profileManager.deleteProfile(profile)
                            }
                            .disabled(profileManager.profiles.count <= 1)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(14)
                    }
                }

                if isEditing {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Profile name", text: $editingProfileName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        HStack(spacing: 10) {
                            Button("Save") {
                                profileManager.renameProfile(profile, to: editingProfileName)
                                editingProfileID = nil
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button("Cancel") {
                                editingProfileID = nil
                                editingProfileName = ""
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("Open profile")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private var createProfileCard: some View {
        Group {
            if creatingProfile {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 8]))
                            .foregroundStyle(Color.white.opacity(0.28))
                            .frame(height: 128)

                        iconPickerButton(
                            iconName: selectedIcon,
                            foreground: Color.white,
                            background: Color.white.opacity(0.1)
                        ) { icon in
                            selectedIcon = icon
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Profile name", text: $newProfileName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        HStack(spacing: 10) {
                            Button("Create") {
                                let profile = profileManager.createProfile(named: newProfileName, iconName: selectedIcon)
                                newProfileName = ""
                                selectedIcon = "person.crop.circle"
                                creatingProfile = false
                                profileID = profile.id
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button("Cancel") {
                                newProfileName = ""
                                selectedIcon = "person.crop.circle"
                                creatingProfile = false
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                        }
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 26))
            } else {
                Button {
                    creatingProfile = true
                    editingProfileID = nil
                } label: {
                    VStack(spacing: 18) {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 8]))
                            .foregroundStyle(Color.white.opacity(0.28))
                            .frame(height: 128)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.88))
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Create profile")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)

                            Text("Add another profile")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.68))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
            }
        }
    }

    private func iconPickerButton(
        iconName: String,
        foreground: Color,
        background: Color,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(availableIcons, id: \.self) { icon in
                Button {
                    onSelect(icon)
                } label: {
                    Label(iconLabel(for: icon), systemImage: icon)
                }
            }
        } label: {
            Circle()
                .fill(background)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(foreground)
                )
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private func iconLabel(for icon: String) -> String {
        switch icon {
        case "person.crop.circle":
            return "Person"
        case "star.fill":
            return "Star"
        case "gamecontroller.fill":
            return "Gaming"
        case "briefcase.fill":
            return "Work"
        case "moon.stars.fill":
            return "Night"
        case "sparkles":
            return "Sparkles"
        case "heart.fill":
            return "Heart"
        case "leaf.fill":
            return "Leaf"
        case "flame.fill":
            return "Flame"
        default:
            return "Icon"
        }
    }
}
