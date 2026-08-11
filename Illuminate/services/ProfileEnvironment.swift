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

@MainActor
final class ProfileEnvironment: ObservableObject {
    let profile: BrowserProfile
    let isGuestSession: Bool
    
    let tabManager: TabManager
    let webKitManager: WebKitManager
    let passwordService: PasswordService
    let adBlockService: AdBlockService
    let trackerBlockingService: TrackerBlockingService
    let websitePermissionService: WebsitePermissionService
    let urlSynchronizer: URLSynchronizer
    let viewModel: ContentViewModel
    let historyManager: HistoryManager
    
    let modelContainer: ModelContainer
    
    init(
        profile: BrowserProfile,
        modelContainer: ModelContainer,
        isGuestSession: Bool = false,
        sessionIdentifier: UUID? = nil
    ) {
        self.profile = profile
        self.isGuestSession = isGuestSession
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
