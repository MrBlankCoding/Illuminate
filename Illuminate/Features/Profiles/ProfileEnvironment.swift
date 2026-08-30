//
//  ProfileEnvironment.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import Foundation
import Observation
import SwiftData
import SwiftUI


@MainActor
@Observable
final class ProfileEnvironment {
    @ObservationIgnored let profile: BrowserProfile
    @ObservationIgnored let isGuestSession: Bool
    @ObservationIgnored let sessionIdentifier: UUID?

    @ObservationIgnored var windowRoute: BrowserWindowRoute {
        isGuestSession ? .guest(sessionIdentifier ?? UUID()) : .profile(profile.id)
    }

    @ObservationIgnored let tabManager: TabManager
    @ObservationIgnored let webKitManager: WebKitManager
    @ObservationIgnored let passwordService: PasswordService
    @ObservationIgnored let trackerBlockingService: TrackerBlockingService
    @ObservationIgnored let websitePermissionService: WebsitePermissionService
    @ObservationIgnored let canvasFingerprintingService: CanvasFingerprintingService
    @ObservationIgnored let urlSynchronizer: URLSynchronizer
    @ObservationIgnored let viewModel: ContentViewModel
    @ObservationIgnored let historyManager: HistoryManager
    @ObservationIgnored let extensionManager: ExtensionManager
    @ObservationIgnored let downloadHistoryStore: DownloadHistoryStore

    @ObservationIgnored let modelContainer: ModelContainer

    var isTornDown = false

    init(
        profile: BrowserProfile,
        modelContainer: ModelContainer,
        isGuestSession: Bool = false,
        sessionIdentifier: UUID? = nil
    ) {
        self.profile = profile
        self.isGuestSession = isGuestSession
        self.sessionIdentifier = sessionIdentifier
        self.modelContainer = modelContainer
        self.urlSynchronizer = URLSynchronizer()
        self.historyManager = HistoryManager(
            modelContainer: modelContainer,
            profileID: isGuestSession ? nil : profile.id,
            isGuestSession: isGuestSession
        )
        self.extensionManager = ExtensionManager(
            profileID: isGuestSession ? nil : profile.id,
            isGuestSession: isGuestSession
        )
        self.extensionManager.scheduleAutoUpdates()
        self.downloadHistoryStore = DownloadHistoryStore(
            profileID: isGuestSession ? nil : profile.id,
            isGuestSession: isGuestSession,
            modelContainer: modelContainer
        )
        DownloadHistoryRegistry.shared.register(self.downloadHistoryStore)
        self.tabManager = TabManager(
            profileID: isGuestSession ? nil : profile.id,
            urlSynchronizer: self.urlSynchronizer,
            isPersistenceEnabled: !isGuestSession,
            extensionManager: self.extensionManager
        )
        self.webKitManager = WebKitManager(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession,
            extensionManager: self.extensionManager
        )
        self.passwordService = PasswordService(
            profileID: isGuestSession ? nil : profile.id,
            container: modelContainer
        )
        self.trackerBlockingService = TrackerBlockingService(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession
        )
        self.websitePermissionService = WebsitePermissionService(
            profileID: isGuestSession ? nil : profile.id,
            persists: !isGuestSession
        )
        self.canvasFingerprintingService = CanvasFingerprintingService(
            profileID: isGuestSession ? nil : profile.id,
            persists: !isGuestSession
        )
        self.viewModel = ContentViewModel(
            tabManager: self.tabManager,
            urlSynchronizer: self.urlSynchronizer,
            historyManager: self.historyManager
        )
    }
    
    func prepareForRemoval() {
        guard !isTornDown else { return }
        isTornDown = true
        AppLog.info("Tearing down environment (profile: \(self.profile.id.uuidString), guest: \(self.isGuestSession))")
        extensionManager.prepareForRemoval()
        webKitManager.prepareForRemoval()
        tabManager.prepareForRemoval()
        historyManager.prepareForRemoval()
        trackerBlockingService.prepareForRemoval()
        websitePermissionService.prepareForRemoval()
        DownloadHistoryRegistry.shared.unregister(downloadHistoryStore)
    }

    deinit {
        #if DEBUG
        print("ProfileEnvironment deallocated (profile: \(profile.id))")
        #endif
    }
}

struct ActiveEnvironmentKey: FocusedValueKey {
    typealias Value = ProfileEnvironment
}

extension FocusedValues {
    var activeEnvironment: ProfileEnvironment? {
        get { self[ActiveEnvironmentKey.self] }
        set { self[ActiveEnvironmentKey.self] = newValue }
    }
}