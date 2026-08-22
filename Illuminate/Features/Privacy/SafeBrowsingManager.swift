//
//  SafeBrowsingManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

// AGAIN!
// This really is just a placeholder right now
// malware.test lolllll
import Foundation

enum SafeBrowsingManager {
    private static let blockedHosts: Set<String> = [
        "malware.test",
        "phishing.test"
    ]

    static func isUnsafe(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }

        return blockedHosts.contains(host)
    }
}
