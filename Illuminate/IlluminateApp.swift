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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let keyboardShortcutHandler: KeyboardShortcutHandler
    private let backgroundResourceManager: BackgroundResourceManager
    private let runtimeSecurityMonitor: RuntimeSecurityMonitor

    let modelContainer: ModelContainer

    init() {
        _profileManager = StateObject(wrappedValue: ProfileManager())

        let center = NotificationCenter.default
        keyboardShortcutHandler    = KeyboardShortcutHandler(notificationCenter: center)
        backgroundResourceManager  = BackgroundResourceManager()
        runtimeSecurityMonitor     = RuntimeSecurityMonitor(notificationCenter: center)

        do {
            modelContainer = try ModelContainer(for: Bookmark.self, Password.self, HistoryEntry.self, DownloadRecord.self)
        } catch {
            AppLog.error("Failed to create ModelContainer — resetting store and retrying", error: error)
            Self.resetStore()
            do {
                modelContainer = try ModelContainer(for: Bookmark.self, Password.self, HistoryEntry.self, DownloadRecord.self)
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }

    private static func resetStore() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("default.store")
        guard let storeURL = base else { return }
        let shm = storeURL.deletingPathExtension().appendingPathExtension("store-shm")
        let wal = storeURL.deletingPathExtension().appendingPathExtension("store-wal")
        for url in [storeURL, shm, wal] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    var body: some Scene {
        WindowGroup(id: Self.profileSelectionWindowID) {
            AppRootView(route: .constant(nil), isStandalone: true, modelContainer: modelContainer)
                .environmentObject(profileManager)
                .frame(
                    maxWidth:  Self.profileWindowSize.width,
                    maxHeight: Self.profileWindowSize.height
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        runtimeSecurityMonitor.startMonitoring()
                        backgroundResourceManager.start()
                    }
                }
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
                .modelContainer(modelContainer)
        }

        Window("Welcome to Illuminate", id: OnboardingView.windowID) {
            OnboardingView()
        }
        .defaultSize(width: 520, height: 430)
        .windowResizability(.contentSize)
    }
}
