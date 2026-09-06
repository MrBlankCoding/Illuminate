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
    @Environment(ProfileManager.self) private var profileManager: ProfileManager
    @State private var hasInterceptedWindowClose = false

    var body: some View {
        Group {
            if let route, let env = profileManager.environment(for: route, container: modelContainer) {
                ContentView()
                    .environment(env)
                    .environment(env.tabManager)
                    .environment(env.viewModel)
                    .environment(env.passwordService)
                    .environment(env.webKitManager)
                    .environment(env.urlSynchronizer)
                    .environment(env.trackerBlockingService)
                    .environment(env.websitePermissionService)
                    .environment(env.canvasFingerprintingService)
                    .environment(env.historyManager)
                    .environment(env.extensionManager)
                    .focusedSceneValue(\.activeEnvironment, env)
                    .id(route)
                    .onAppear {
                        env.ensureStartupServicesAreReady()
                        env.tabManager.ensureHasAtLeastOneTab()
                        registerDockMenuRoutes()
                        if !hasInterceptedWindowClose {
                            hasInterceptedWindowClose = true
                            Task { @MainActor in
                                await Task.yield()
                                if let window = NSApp.keyWindow {
                                    installUnsavedChangesInterceptor(on: window)
                                    (window.delegate as? UnsavedChangesWindowDelegate)?.hasDirtyTabs = {
                                        env.tabManager.tabs.contains { $0.isDirty }
                                    }
                                }
                            }
                        }
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
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkTab)) { _ in
            guard let route,
                  let env = profileManager.environment(for: route, container: modelContainer),
                  !env.isGuestSession else { return }
            env.tabManager.toggleBookmark(context: modelContainer.mainContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearHistory)) { _ in
            guard let route,
                  let env = profileManager.environment(for: route, container: modelContainer),
                  !env.isGuestSession else { return }
            env.historyManager.clearAll()
            ToastEvent.post(icon: "trash", message: "History cleared")
        }
        .onAppear {
            presentOnboardingIfNeeded()
        }
        .onChange(of: AppFileOpening.shared.needsBrowserWindow) { _, _ in
            openBrowserWindowForPendingFilesIfNeeded()
        }
        .onChange(of: WebURLOpening.shared.needsBrowserWindow) { _, _ in
            openBrowserWindowForPendingWebURLsIfNeeded()
        }
        .onChange(of: profileManager.profiles) { _, _ in
            openBrowserWindowForPendingFilesIfNeeded()
        }
        .overlay(alignment: .top) { ToastOverlay() }
    }

    @Environment(\.openWindow) private var openWindow

    private func presentOnboardingIfNeeded() {
        guard isStandalone, !hasCompletedOnboarding, !hasRequestedOnboarding else { return }
        guard !ProcessInfo.processInfo.arguments.contains(where: { $0.caseInsensitiveCompare("-uiTesting") == .orderedSame }) else { return }
        hasRequestedOnboarding = true
        openWindow(id: OnboardingView.windowID)
    }

    private func openBrowserWindowForPendingFilesIfNeeded() {
        guard AppFileOpening.shared.needsBrowserWindow, route == nil else { return }
        guard let profileID = profileManager.preferredProfileID else { return }
        AppFileOpening.shared.clearNeedsBrowserWindow()
        openProfileWindow(profileID)
    }

    private func openBrowserWindowForPendingWebURLsIfNeeded() {
        guard WebURLOpening.shared.needsBrowserWindow, route == nil else { return }
        guard let profileID = profileManager.preferredProfileID else { return }
        WebURLOpening.shared.needsBrowserWindow = false
        openProfileWindow(profileID)
    }

    private func openProfileWindow(_ profileID: UUID) {
        guard BrowserWindowRegistry.shared.beginOpening(for: profileID) else { return }
        openWindow(value: BrowserWindowRoute.profile(profileID))
    }

    private func registerDockMenuRoutes() {
        DockMenuWindowRouter.shared.openProfileSelection = {
            DockMenuWindowRouter.shared.requestProfileSelection {
                openWindow(id: ProfileSelectionView.windowID)
            }
        }
        DockMenuWindowRouter.shared.openProfile = { profileID in
            openWindow(value: BrowserWindowRoute.profile(profileID))
        }
        DockMenuWindowRouter.shared.openGuest = {
            openWindow(value: BrowserWindowRoute.guest(UUID()))
        }
    }
}
