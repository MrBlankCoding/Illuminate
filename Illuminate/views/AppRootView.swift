//
//  AppRootView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/22/26.
//

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Binding var route: BrowserWindowRoute?
    let modelContainer: ModelContainer
    @EnvironmentObject private var profileManager: ProfileManager

    var body: some View {
        Group {
            if let route, let env = profileManager.environment(for: route, container: modelContainer) {
                ContentView()
                    .environmentObject(env)
                    .environmentObject(env.tabManager)
                    .environmentObject(env.viewModel)
                    .environmentObject(env.passwordService)
                    .environmentObject(env.webKitManager)
                    .environmentObject(env.urlSynchronizer)
                    .environmentObject(env.adBlockService)
                    .environmentObject(env.redirectProtectionService)
                    .focusedSceneValue(\.activeEnvironment, env)
                    .id(route)
            } else {
                ProfileSelectionView(route: $route)
            }
        }
    }
}
