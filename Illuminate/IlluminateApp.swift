//
//  IlluminateApp.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import SwiftData

@main
struct IlluminateApp: App {
    private static let profileSelectionWindowID = "profile-selection-window"
    private static let profileWindowSize = CGSize(width: 320, height: 220)   // single source of truth
    private static let browserWindowSize  = CGSize(width: 1180, height: 720)
    @StateObject private var profileManager: ProfileManager
    @StateObject private var settingsTabManager = TabManager(isPersistenceEnabled: false)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let keyboardShortcutHandler: KeyboardShortcutHandler
    private let backgroundResourceManager: BackgroundResourceManager
    private let runtimeSecurityMonitor: RuntimeSecurityMonitor
    private let passkeyAuthorizationService: PasskeyAuthorizationService


    let modelContainer: ModelContainer

    init() {
        UITestLaunchConfiguration.prepareAppStateIfNeeded()
        _profileManager = StateObject(wrappedValue: ProfileManager())

        let center = NotificationCenter.default
        keyboardShortcutHandler    = KeyboardShortcutHandler(notificationCenter: center)
        backgroundResourceManager  = BackgroundResourceManager()
        runtimeSecurityMonitor     = RuntimeSecurityMonitor(notificationCenter: center)
        passkeyAuthorizationService = .shared

        do {
            let container: ModelContainer
            if UITestLaunchConfiguration.isRunningUITests {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Bookmark.self, Password.self,
                                               configurations: configuration)
            } else {
                container = try ModelContainer(for: Bookmark.self, Password.self)
            }
            modelContainer = container
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }

        runtimeSecurityMonitor.startMonitoring()
        backgroundResourceManager.start()
        passkeyAuthorizationService.requestAccessIfNeeded()
    }

    var body: some Scene {
        WindowGroup(id: Self.profileSelectionWindowID) {
            AppRootView(route: .constant(nil), isStandalone: true, modelContainer: modelContainer)
                .environmentObject(profileManager)
                .frame(
                    maxWidth:  Self.profileWindowSize.width,
                    maxHeight: Self.profileWindowSize.height
                )
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .defaultSize(Self.profileWindowSize)
        .windowResizability(.contentSize)

        WindowGroup(for: BrowserWindowRoute.self) { $route in
            AppRootView(route: $route, modelContainer: modelContainer)
                .environmentObject(profileManager)
                .frame(minWidth: 600, minHeight: 450)
                .onOpenURL { url in
                    guard let request = BrowserWindowOpenRequest(url: url) else { return }
                    switch request {
                    case .profileSelection:     route = nil
                    case let .route(windowRoute): route = windowRoute
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .defaultSize(Self.browserWindowSize)
        .commands {
            AppCommands(shortcutHandler: keyboardShortcutHandler)
            BookmarksCommands(modelContainer: modelContainer)
            ProfileCommands(profileManager: profileManager)
        }

        Settings {
            NativeSettingsView()
                .environmentObject(settingsTabManager)
                .modelContainer(modelContainer)
        }
    }
}
