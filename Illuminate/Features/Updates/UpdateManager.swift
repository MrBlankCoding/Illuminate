//
//  UpdateManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/25/26.
//

import Combine
import Foundation
import Sparkle

@MainActor
@Observable
final class UpdateManager {
    
    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()
    
    var canCheckForUpdates = false
    
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
    
    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }
    
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Bridge Sparkle's KVO canCheckForUpdates to @Observable
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
            .store(in: &cancellables)
        
        configureDefaultBehavior()
        logConfiguration()
    }
    
    
    private func configureDefaultBehavior() {
        updaterController.updater.automaticallyChecksForUpdates = true
        updaterController.updater.updateCheckInterval = 86400
        updaterController.updater.automaticallyDownloadsUpdates = false
    }
    
    private func logConfiguration() {
        // Log configuration status for debugging
        if let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String {
            AppLog.debug("Sparkle feed URL: \(feedURL)")
        } else {
            AppLog.warning("Sparkle: No SUFeedURL configured in Info.plist")
        }
        
        if let _ = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String {
            AppLog.debug("Sparkle: EdDSA public key is configured")
        } else {
            AppLog.warning("Sparkle: No SUPublicEDKey configured - updates will use code signing only (deprecated)")
            AppLog.info("To fix: Generate keys with `sign_update --generate-keys` and add SUPublicEDKey to Info.plist")
        }
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }
    
    var lastUpdateCheckDate: Date? {
        updaterController.updater.lastUpdateCheckDate
    }
    
    func resetUpdateCycle() {
        updaterController.updater.resetUpdateCycle()
    }
}

extension UpdateManager {
    static var feedURL: URL? {
        // You can configure this in Info.plist with SUFeedURL key
        // or return a URL here directly:
        // return URL(string: "https://yourdomain.com/appcast.xml")
        return nil
    }
    
    static var sendsSystemProfile: Bool {
        return false
    }
}
