//
//  IlluminatePage.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/20/26.
//

import Foundation
import SwiftUI

enum IlluminatePage: String, CaseIterable, Equatable {
    case passwords
    case cookies
    case protection
    case downloads
    case history
    case permissions
    case info

    static let urlScheme = "illuminate"

    init?(url: URL) {
        guard
            url.scheme?.localizedCaseInsensitiveCompare(Self.urlScheme) == .orderedSame,
            let host = url.host?.lowercased(),
            let page = IlluminatePage(rawValue: host)
        else { return nil }
        self = page
    }

    var url: URL {
        URL(string: "\(Self.urlScheme)://\(rawValue)")!
    }

    var title: String {
        switch self {
        case .passwords: return "Passwords"
        case .cookies: return "Cookies & Website Data"
        case .protection: return "Privacy & Protection"
        case .downloads: return "Downloads"
        case .history: return "History"
        case .permissions: return "Permissions"
        case .info: return "Browser Info & Diagnostics"
        }
    }

    var tabTitle: String {
        switch self {
        case .passwords: return "Passwords"
        case .cookies: return "Cookies"
        case .protection: return "Protection"
        case .downloads: return "Downloads"
        case .history: return "History"
        case .permissions: return "Permissions"
        case .info: return "Browser Info"
        }
    }

    var icon: String {
        switch self {
        case .passwords: return "key.fill"
        case .cookies: return "circle.hexagongrid.fill"
        case .protection: return "shield.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .history: return "clock.arrow.circlepath"
        case .permissions: return "hand.raised.fill"
        case .info: return "info.circle.fill"
        }
    }

    var keywords: [String] {
        switch self {
        case .passwords: return ["passwords", "credentials", "logins", "keys", "accounts", "autofill"]
        case .cookies: return ["cookies", "cache", "data", "storage", "website data"]
        case .protection: return ["protection", "privacy", "adblock", "tracker", "security", "https", "shield"]
        case .downloads: return ["downloads", "files", "transfers"]
        case .history: return ["history", "recent", "visited", "sites", "logs"]
        case .permissions: return ["permissions", "camera", "microphone", "location", "notifications", "sites"]
        case .info: return ["info", "about", "diagnostics", "user agent", "profile", "debug", "version", "system"]
        }
    }
}
