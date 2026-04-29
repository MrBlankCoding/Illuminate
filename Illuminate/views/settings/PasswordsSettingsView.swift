//
//  PasswordsSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI
import SwiftData

struct PasswordsSettingsView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @Environment(\.modelContext) private var modelContext
    @Query private var passwords: [Password]
    @State private var passwordSearchText = ""

    private var filteredPasswords: [Password] {
        guard environment.isGuestSession == false else { return [] }

        let scopedPasswords = passwords.filter {
            $0.profileID == environment.profile.id || $0.profileID == nil
        }
        let query = passwordSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return scopedPasswords }

        return scopedPasswords.filter {
            $0.url.lowercased().contains(query) || $0.username.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsShared.panelSection {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)

                            TextField("Search URLs or usernames", text: $passwordSearchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium))
                                .accessibilityIdentifier("settings.passwords.searchField")
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(SettingsShared.glassBox(cornerRadius: 16))

                        SettingsShared.metricsPill(value: "\(filteredPasswords.count)", label: "Visible")
                    }

                    if filteredPasswords.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: environment.isGuestSession ? "person.fill.questionmark" : (passwordSearchText.isEmpty ? "lock.slash" : "magnifyingglass.circle"))
                                .font(.system(size: 30))
                                .foregroundStyle(tabManager.windowThemeColor.opacity(0.7))
                            Text(
                                environment.isGuestSession
                                    ? "Guest sessions do not keep saved passwords"
                                    : (passwordSearchText.isEmpty ? "No saved passwords yet" : "No matching passwords")
                            )
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                        .background(SettingsShared.glassBox(cornerRadius: 22))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredPasswords) { password in
                                passwordRow(password)
                            }
                        }
                    }
                }
            }
        }
    }

    private func passwordRow(_ password: Password) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(tabManager.windowThemeColor.opacity(0.12))

                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tabManager.windowThemeColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(password.url)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(password.username)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(password.passwordData, forType: .string)
            } label: {
                SettingsShared.actionCapsule(icon: "doc.on.doc", title: "Copy", tint: tabManager.windowThemeColor)
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .help("Copy password")

            Button(role: .destructive) {
                modelContext.delete(password)
                try? modelContext.save()
            } label: {
                SettingsShared.actionCapsule(icon: "trash", title: "Delete", tint: .red.opacity(0.72))
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .help("Delete")
        }
        .padding(14)
        .background(SettingsShared.glassBox(cornerRadius: 20))
    }
}
