//
//  PasswordsPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftData
import SwiftUI
import Observation

// illuminate://passwords

struct PasswordsPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @Environment(\.modelContext) private var modelContext
    @Query private var passwords: [Password]
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var revealedIDs: Set<PersistentIdentifier> = []

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    private var filteredPasswords: [Password] {
        guard !environment.isGuestSession else { return [] }
        let scoped = passwords.filter {
            $0.profileID == environment.profile.id || $0.profileID == nil
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return scoped }
        return scoped.filter {
            $0.url.lowercased().contains(q) || $0.username.lowercased().contains(q)
        }
    }

    var body: some View {
        InternalPage(
            icon: "key.fill",
            title: "Passwords",
            accentColor: tabManager.windowThemeColor
        ) {
            if environment.isGuestSession {
                InternalPageEmptyState(
                    icon: "person.fill.questionmark",
                    message: "Passwords aren't saved in Guest sessions."
                )
            } else {
                VStack(spacing: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search URLs or usernames", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                    if filteredPasswords.isEmpty {
                        InternalPageEmptyState(
                            icon: searchText.isEmpty ? "lock.slash" : "magnifyingglass",
                            message: searchText.isEmpty ? "No saved passwords." : "No matching passwords."
                        )
                    } else {
                        VStack(spacing: 1) {
                            ForEach(filteredPasswords) { password in
                                passwordRow(password)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func passwordRow(_ password: Password) -> some View {
        let isRevealed = revealedIDs.contains(password.id)

        HStack(spacing: 12) {
            // favcoin placeholder
            // need to work on favcoin logic
            ZStack {
                Circle()
                    .fill(tabManager.windowThemeColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tabManager.windowThemeColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(password.url)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(password.username)
                    if let email = password.email, !email.isEmpty {
                        Text("•")
                        Text(email)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    if isRevealed {
                        revealedIDs.remove(password.id)
                    } else {
                        revealedIDs.insert(password.id)
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide password" : "Show password")

                if isRevealed {
                    Text(password.passwordData)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .transition(.opacity)
                }

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(password.passwordData, forType: .string)
                }
                .buttonStyle(InternalPageChipButtonStyle(color: tabManager.windowThemeColor))

                Button("Delete") {
                    revealedIDs.remove(password.id)
                    modelContext.delete(password)
                    try? modelContext.save()
                }
                .buttonStyle(InternalPageChipButtonStyle(color: .red))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}
