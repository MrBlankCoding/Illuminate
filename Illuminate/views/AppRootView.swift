//
//  AppRootView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/22/26.
//

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Binding var profileID: UUID?
    let modelContainer: ModelContainer
    @EnvironmentObject private var profileManager: ProfileManager

    var body: some View {
        Group {
            if let id = profileID, let env = profileManager.environment(for: id, container: modelContainer) {
                ContentView()
                    .environmentObject(env)
                    .environmentObject(env.tabManager)
                    .environmentObject(env.viewModel)
                    .environmentObject(env.passwordService)
                    .environmentObject(env.webKitManager)
                    .environmentObject(env.urlSynchronizer)
                    .environmentObject(env.adBlockService)
                    .focusedSceneValue(\.activeEnvironment, env)
                    .id(id)
            } else {
                ProfileSelectionView(profileID: $profileID)
            }
        }
    }
}
