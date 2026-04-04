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
        }

        CommandMenu("Profiles") {
            NewWindowButton()
            Divider()

            ForEach(profileManager.profiles) { profile in
                OpenProfileWindowButton(profile: profile)
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
    }
}

struct OpenProfileWindowButton: View {
    let profile: BrowserProfile
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button {
            openWindow(value: BrowserWindowRoute.profile(profile.id))
        } label: {
            HStack {
                Text(profile.name)
                Image(systemName: profile.iconName)
            }
        }
    }
}
