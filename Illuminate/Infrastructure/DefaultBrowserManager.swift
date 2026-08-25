//
//  DefaultBrowserManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import Foundation

enum DefaultBrowserManager {
    static var isDefaultBrowser: Bool {
        guard let probeURL = URL(string: "https://www.apple.com") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: probeURL) == Bundle.main.bundleURL
    }

    static func setDefaultBrowser(completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let appURL = Bundle.main.bundleURL
            for scheme in ["http", "https"] {
                try? await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme)
            }
            completion(isDefaultBrowser)
        }
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") ??
            URL(string: "x-apple.systempreferences:com.apple.preferences")!
        NSWorkspace.shared.open(url)
    }
}
