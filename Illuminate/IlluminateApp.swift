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
    @StateObject private var profileManager = ProfileManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let keyboardShortcutHandler: KeyboardShortcutHandler
    private let backgroundResourceManager: BackgroundResourceManager
    private let runtimeSecurityMonitor: RuntimeSecurityMonitor
    let modelContainer: ModelContainer
    
    init() {
        let center = NotificationCenter.default
        keyboardShortcutHandler = KeyboardShortcutHandler(notificationCenter: center)
        backgroundResourceManager = BackgroundResourceManager()
        runtimeSecurityMonitor = RuntimeSecurityMonitor(notificationCenter: center)
        do {
            modelContainer = try ModelContainer(for: Bookmark.self, Password.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        
        runtimeSecurityMonitor.startMonitoring()
        backgroundResourceManager.start()
        configureNotificationLogging(notificationCenter: center)
    }

    var body: some Scene {
        WindowGroup(for: BrowserProfile.ID.self) { $profileID in
            AppRootView(profileID: $profileID, modelContainer: modelContainer)
                .environmentObject(profileManager)
                .frame(minWidth: 600, minHeight: 450)
                .onOpenURL { url in
                    // In a multi-window setup, the `onOpenURL` might need to route to a specific window
                    // For now, it could be handled by the focused window
                }
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 720)
        .commands {
            AppCommands(shortcutHandler: keyboardShortcutHandler)
            BookmarksCommands(
                shortcutHandler: keyboardShortcutHandler,
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
