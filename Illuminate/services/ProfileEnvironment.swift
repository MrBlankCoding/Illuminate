//
//  ProfileEnvironment.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import Combine
import Foundation
import SwiftData
import SwiftUI
import os


@MainActor
final class ProfileEnvironment: ObservableObject {
    let profile: BrowserProfile
    let isGuestSession: Bool
    let sessionIdentifier: UUID?

    let tabManager: TabManager
    let webKitManager: WebKitManager
    let passwordService: PasswordService
    let adBlockService: AdBlockService
    let trackerBlockingService: TrackerBlockingService
    let websitePermissionService: WebsitePermissionService
    let canvasFingerprintingService: CanvasFingerprintingService
    let urlSynchronizer: URLSynchronizer
    let viewModel: ContentViewModel
    let historyManager: HistoryManager

    let modelContainer: ModelContainer

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.illuminate.browser",
        category: "ProfileEnvironment"
    )

    private(set) var isTornDown = false

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
        self.tabManager = TabManager(
            profileID: isGuestSession ? nil : profile.id,
            urlSynchronizer: self.urlSynchronizer,
            isPersistenceEnabled: !isGuestSession
        )
        self.webKitManager = WebKitManager(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession
        )
        self.passwordService = PasswordService(
            profileID: isGuestSession ? nil : profile.id,
            container: modelContainer
        )
        self.adBlockService = AdBlockService(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession,
            ruleListIdentifier: "IlluminateAdBlockRules-\((sessionIdentifier ?? profile.id).uuidString)"
        )
        self.trackerBlockingService = TrackerBlockingService(
            profileID: isGuestSession ? nil : profile.id,
            isPersistenceEnabled: !isGuestSession,
            adBlockService: self.adBlockService
        )
        self.websitePermissionService = WebsitePermissionService(
            profileID: isGuestSession ? nil : profile.id,
            persists: !isGuestSession
        )
        self.canvasFingerprintingService = CanvasFingerprintingService(
            profileID: isGuestSession ? nil : profile.id,
            persists: !isGuestSession
        )
        self.historyManager = HistoryManager(
            modelContainer: modelContainer,
            profileID: isGuestSession ? nil : profile.id,
            isGuestSession: isGuestSession
        )
        self.viewModel = ContentViewModel(
            tabManager: self.tabManager,
            urlSynchronizer: self.urlSynchronizer
        )
    }
    
    func prepareForRemoval() {
        guard !isTornDown else { return }
        isTornDown = true
        logger.debug("Tearing down environment (profile: \(self.profile.id.uuidString, privacy: .public), guest: \(self.isGuestSession))")
        // TODO: as services gain explicit teardown APIs (e.g. removing the
        // WKContentRuleList registered under `adBlockService`'s
        // ruleListIdentifier, or closing WebKit process pools), invoke them
        // here so guest sessions and deleted profiles don't leak OS-level
        // resources for the remaining lifetime of the app.
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