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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasRequestedOnboarding = false
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
                    .environmentObject(env.extensionManager)
                    .focusedSceneValue(\.activeEnvironment, env)
                    .id(route)
                    .onAppear {
                        env.tabManager.ensureHasAtLeastOneTab()
                        registerDockMenuRoutes()
                    }
                    .task {
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        env.historyManager.loadInitialData()
                    }
            } else {
                ProfileSelectionView(
                    route: $route,
                    isStandalone: isStandalone,
                    prewarmProfile: { profileID in
                        profileManager.prewarmProfileEnvironment(for: profileID, container: modelContainer)
                    }
                )
            }
        }
        .task(id: profileManager.profiles) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            profileManager.prewarmLastUsedProfileEnvironment(container: modelContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPrivateWindow)) { _ in
            openWindow(value: BrowserWindowRoute.guest(UUID()))
        }
        .onAppear {
            presentOnboardingIfNeeded()
        }
    }

    @Environment(\.openWindow) private var openWindow

    private func presentOnboardingIfNeeded() {
        guard isStandalone, !hasCompletedOnboarding, !hasRequestedOnboarding else { return }
        guard !ProcessInfo.processInfo.arguments.contains("-UITest") else { return }
        hasRequestedOnboarding = true
        openWindow(id: OnboardingView.windowID)
    }

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
