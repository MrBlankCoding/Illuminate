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

    @ObservationIgnored private var urlSynchronizerStorage: URLSynchronizer?
    @ObservationIgnored private var historyManagerStorage: HistoryManager?
    @ObservationIgnored private var extensionManagerStorage: ExtensionManager?
    @ObservationIgnored private var downloadHistoryStoreStorage: DownloadHistoryStore?
    @ObservationIgnored private var easelManagerStorage: EaselManager?
    @ObservationIgnored private var tabManagerStorage: TabManager?
    @ObservationIgnored private var webKitManagerStorage: WebKitManager?
    @ObservationIgnored private var passwordServiceStorage: PasswordService?
    @ObservationIgnored private var trackerBlockingServiceStorage: TrackerBlockingService?
    @ObservationIgnored private var websitePermissionServiceStorage: WebsitePermissionService?
    @ObservationIgnored private var canvasFingerprintingServiceStorage: CanvasFingerprintingService?
    @ObservationIgnored private var viewModelStorage: ContentViewModel?

    var urlSynchronizer: URLSynchronizer {
        if let existing = urlSynchronizerStorage { return existing }
        let value = URLSynchronizer()
        urlSynchronizerStorage = value
        return value
    }

    var historyManager: HistoryManager {
        if let existing = historyManagerStorage { return existing }
        let value = HistoryManager(
            modelContainer: modelContainer,
            profileID: isGuestSession ? nil : profile.id,
            isGuestSession: isGuestSession
        )
        historyManagerStorage = value
        return value
    }

    var extensionManager: ExtensionManager {
        if let existing = extensionManagerStorage { return existing }
        let value = ExtensionManager(
            profileID: isGuestSession ? nil : profile.id,
            isGuestSession: isGuestSession
        )
        value.scheduleAutoUpdates()
        extensionManagerStorage = value
        return value
    }

    var downloadHistoryStore: DownloadHistoryStore {
        if let existing = downloadHistoryStoreStorage { return existing }
        let value = DownloadHistoryStore(
            profileID: isGuestSession ? nil : profile.id,
            isGuestSession: isGuestSession,
            modelContainer: modelContainer
        )
        DownloadHistoryRegistry.shared.register(value)
        downloadHistoryStoreStorage = value
        return value
    }

    var easelManager: EaselManager {
        if let existing = easelManagerStorage { return existing }
        let value = EaselManager(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession
        )
        easelManagerStorage = value
        return value
    }

    var tabManager: TabManager {
        if let existing = tabManagerStorage { return existing }
        let value = TabManager(
            profileID: isGuestSession ? nil : profile.id,
            urlSynchronizer: self.urlSynchronizer,
            isPersistenceEnabled: !isGuestSession,
            extensionManager: self.extensionManager
        )
        value.easelManager = self.easelManager
        tabManagerStorage = value
        return value
    }

    var webKitManager: WebKitManager {
        if let existing = webKitManagerStorage { return existing }
        let value = WebKitManager(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession,
            extensionManager: self.extensionManager
        )
        webKitManagerStorage = value
        return value
    }

    var passwordService: PasswordService {
        if let existing = passwordServiceStorage { return existing }
        let value = PasswordService(
            profileID: isGuestSession ? nil : profile.id,
            container: modelContainer
        )
        passwordServiceStorage = value
        return value
    }

    var trackerBlockingService: TrackerBlockingService {
        if let existing = trackerBlockingServiceStorage { return existing }
        let value = TrackerBlockingService(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession
        )
        trackerBlockingServiceStorage = value
        return value
    }

    var websitePermissionService: WebsitePermissionService {
        if let existing = websitePermissionServiceStorage { return existing }
        let value = WebsitePermissionService(
            profileID: isGuestSession ? nil : profile.id,
            persists: !isGuestSession
        )
        websitePermissionServiceStorage = value
        return value
    }

    var canvasFingerprintingService: CanvasFingerprintingService {
        if let existing = canvasFingerprintingServiceStorage { return existing }
        let value = CanvasFingerprintingService(
            profileID: isGuestSession ? nil : profile.id,
            persists: !isGuestSession
        )
        canvasFingerprintingServiceStorage = value
        return value
    }

    var viewModel: ContentViewModel {
        if let existing = viewModelStorage { return existing }
        let value = ContentViewModel(
            tabManager: self.tabManager,
            urlSynchronizer: self.urlSynchronizer,
            historyManager: self.historyManager
        )
        viewModelStorage = value
        return value
    }

    @ObservationIgnored let modelContainer: ModelContainer

    var isTornDown = false
    var hasLazyServicesLoaded: Bool {
        webKitManagerStorage != nil || passwordServiceStorage != nil || trackerBlockingServiceStorage != nil
            || websitePermissionServiceStorage != nil || canvasFingerprintingServiceStorage != nil || tabManagerStorage != nil
    }

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
    }

    func ensureStartupServicesAreReady() {
        _ = urlSynchronizer
        _ = extensionManager
        _ = historyManager
        _ = downloadHistoryStore
        _ = easelManager
        _ = tabManager
        _ = webKitManager
        _ = passwordService
        _ = trackerBlockingService
        _ = websitePermissionService
        _ = canvasFingerprintingService
        _ = viewModel
    }

    func prepareForRemoval() {
        guard !isTornDown else { return }
        isTornDown = true
        AppLog.info("Tearing down environment (profile: \(self.profile.id.uuidString), guest: \(self.isGuestSession))")
        extensionManagerStorage?.prepareForRemoval()
        webKitManagerStorage?.prepareForRemoval()
        tabManagerStorage?.prepareForRemoval()
        historyManagerStorage?.prepareForRemoval()
        trackerBlockingServiceStorage?.prepareForRemoval()
        websitePermissionServiceStorage?.prepareForRemoval()
        if let store = downloadHistoryStoreStorage {
            DownloadHistoryRegistry.shared.unregister(store)
        }
    }

    deinit {
        #if DEBUG
        AppLog.debug("ProfileEnvironment deallocated (profile: \(profile.id))")
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