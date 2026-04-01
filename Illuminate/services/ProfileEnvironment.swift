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
    
    let tabManager: TabManager
    let webKitManager: WebKitManager
    let passwordService: PasswordService
    let adBlockService: AdBlockService
    let urlSynchronizer: URLSynchronizer
    let viewModel: ContentViewModel
    
    let modelContainer: ModelContainer
    
    init(profile: BrowserProfile, modelContainer: ModelContainer) {
        self.profile = profile
        self.modelContainer = modelContainer
        
        // Initialize single-profile-scoped services 
        self.urlSynchronizer = URLSynchronizer()
        self.tabManager = TabManager(profile: profile, urlSynchronizer: self.urlSynchronizer)
        self.webKitManager = WebKitManager(profile: profile)
        self.passwordService = PasswordService(profile: profile, container: modelContainer)
        self.adBlockService = AdBlockService(profile: profile)
        self.viewModel = ContentViewModel(tabManager: self.tabManager, urlSynchronizer: self.urlSynchronizer)
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
