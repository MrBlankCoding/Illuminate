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
            // Replaces the standard "New Window" action
            NewWindowButton()
            
            Menu("New Window with Profile") {
                ForEach(profileManager.profiles) { profile in
                    OpenProfileWindowButton(profile: profile)
                }
            }
        }
    }
}

struct NewWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("New Window") {
            // Open the profile selector
            openWindow(value: UUID?.none)
        }
        .keyboardShortcut("n", modifiers: .command)
    }
}

struct OpenProfileWindowButton: View {
    let profile: BrowserProfile
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button {
            openWindow(value: profile.id)
        } label: {
            HStack {
                Text(profile.name)
                Image(systemName: profile.iconName)
            }
        }
    }
}
