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
    var isStandalone: Bool = false
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
                    .environmentObject(env.trackerBlockingService)
                    .environmentObject(env.websitePermissionService)
                    .environmentObject(env.canvasFingerprintingService)
                    .environmentObject(env.historyManager)
                    .focusedSceneValue(\.activeEnvironment, env)
                    .id(route)
                    .onAppear {
                        env.tabManager.ensureHasAtLeastOneTab()
                        registerDockMenuRoutes()
                    }
            } else {
                ProfileSelectionView(route: $route, isStandalone: isStandalone)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPrivateWindow)) { _ in
            openWindow(value: BrowserWindowRoute.guest(UUID()))
        }
    }

    @Environment(\.openWindow) private var openWindow

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
