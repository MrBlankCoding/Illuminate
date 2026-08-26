//
//  ProfileCommands.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import SwiftUI

struct ProfileCommands: Commands {
    @ObservedObject var profileManager: ProfileManager

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            NewWindowButton()
            NewPrivateWindowMenuButton()

            Divider()

            OpenFileCommand()
        }

        CommandMenu("Profiles") {
            NewWindowButton()
            NewPrivateWindowMenuButton()

            Divider()

            ForEach(profileManager.profiles) { profile in
                OpenProfileWindowButton(profile: profile)
            }

            Divider()

            Button("Manage Profiles…") {
                DockMenuWindowRouter.shared.openProfileSelection?()
            }
        }
    }
}

struct NewWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let _ = registerDockMenuRoutes()

        Button("New Window") {
            openWindow(id: "profile-selection-window")
        }
        .keyboardShortcut("n", modifiers: .command)
    }

    @MainActor
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
}


struct NewPrivateWindowMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New Private Window") {
            openWindow(value: BrowserWindowRoute.guest(UUID()))
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}


struct OpenProfileWindowButton: View {
    let profile: BrowserProfile
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(value: BrowserWindowRoute.profile(profile.id))
        } label: {
            Label(profile.name, systemImage: profile.iconName)
        }
    }
}
