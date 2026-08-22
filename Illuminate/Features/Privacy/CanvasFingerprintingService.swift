//
//  CanvasFingerprintingService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/18/26.
//

import Combine
import Foundation

@MainActor
final class CanvasFingerprintingService: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            guard persists else { return }
            userDefaults.set(isEnabled, forKey: storageKey)
        }
    }

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let persists: Bool

    init(profileID: UUID?, userDefaults: UserDefaults = .standard, persists: Bool = true) {
        self.userDefaults = userDefaults
        self.persists = persists
        self.storageKey = profileID.map { "profile.\($0.uuidString).canvasFingerprintingProtection" } ?? "canvasFingerprintingProtection"
        self.isEnabled = persists ? (userDefaults.object(forKey: storageKey) as? Bool ?? true) : true
    }
}
