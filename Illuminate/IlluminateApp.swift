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

    @StateObject private var profileManager: ProfileManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let keyboardShortcutHandler: KeyboardShortcutHandler
    private let backgroundResourceManager: BackgroundResourceManager
    private let runtimeSecurityMonitor: RuntimeSecurityMonitor
    let modelContainer: ModelContainer
    
    init() {
        UITestLaunchConfiguration.prepareAppStateIfNeeded()
        _profileManager = StateObject(wrappedValue: ProfileManager())

        let center = NotificationCenter.default
        keyboardShortcutHandler = KeyboardShortcutHandler(notificationCenter: center)
        backgroundResourceManager = BackgroundResourceManager()
        runtimeSecurityMonitor = RuntimeSecurityMonitor(notificationCenter: center)
        do {
            if UITestLaunchConfiguration.isRunningUITests {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(
                    for: Bookmark.self,
                    Password.self,
                    configurations: configuration
                )
            } else {
                modelContainer = try ModelContainer(for: Bookmark.self, Password.self)
            }
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        
        runtimeSecurityMonitor.startMonitoring()
        backgroundResourceManager.start()
        configureNotificationLogging(notificationCenter: center)
    }

    var body: some Scene {
        WindowGroup(id: Self.profileSelectionWindowID) {
            ProfileSelectionWindowHost(modelContainer: modelContainer)
                .environmentObject(profileManager)
                .frame(minWidth: 600, minHeight: 450)
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 720)

        WindowGroup(for: BrowserWindowRoute.self) { $route in
            AppRootView(route: $route, modelContainer: modelContainer)
                .environmentObject(profileManager)
                .frame(minWidth: 600, minHeight: 450)
                .onOpenURL { url in
                    guard let request = BrowserWindowOpenRequest(url: url) else {
                        return
                    }

                    switch request {
                    case .profileSelection:
                        route = nil
                    case let .route(windowRoute):
                        route = windowRoute
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 720)
        .commands {
            AppCommands(shortcutHandler: keyboardShortcutHandler)
            BookmarksCommands(
                modelContainer: modelContainer
            )
            ProfileCommands(profileManager: profileManager)
        }
    }

    private func configureNotificationLogging(notificationCenter: NotificationCenter) {
        [Notification.Name.newTab, .focusURLBar, .openBookmarks]
            .forEach { name in
                notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                    AppLog.ui("Received event: \(name.rawValue)")
                }
            }
    }
}

private struct ProfileSelectionWindowHost: View {
    let modelContainer: ModelContainer
    @State private var route: BrowserWindowRoute?

    var body: some View {
        AppRootView(route: $route, modelContainer: modelContainer)
    }
}
