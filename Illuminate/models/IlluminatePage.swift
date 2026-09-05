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
    case protection
    case downloads
    case history
    case permissions
    case info
    case extensions
    case easel

    static let urlScheme = "illuminate"
    static var suggestiblePages: [IlluminatePage] {
        allCases
    }

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

    func displayTitle(for url: URL) -> String {
        if self == .easel {
            // title will be overridden by EaselManager; keep generic fallback
            return "Easel"
        }
        return tabTitle
    }

    static func easelID(from url: URL) -> UUID? {
        Easel.id(from: url)
    }

    var title: String {
        switch self {
        case .passwords: return "Passwords"
        case .protection: return "Privacy & Protection"
        case .downloads: return "Downloads"
        case .history: return "History"
        case .permissions: return "Permissions"
        case .info: return "Browser Info & Diagnostics"
        case .extensions: return "Extensions"
        case .easel: return "Easel"
        }
    }

    var tabTitle: String {
        switch self {
        case .passwords: return "Passwords"
        case .protection: return "Protection"
        case .downloads: return "Downloads"
        case .history: return "History"
        case .permissions: return "Permissions"
        case .info: return "Browser Info"
        case .extensions: return "Extensions"
        case .easel: return "Easel"
        }
    }

    var icon: String {
        switch self {
        case .passwords: return "key.fill"
        case .protection: return "shield.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .history: return "clock.arrow.circlepath"
        case .permissions: return "hand.raised.fill"
        case .info: return "info.circle.fill"
        case .extensions: return "puzzlepiece.fill"
        case .easel: return "paintbrush.pointed.fill"
        }
    }

    var keywords: [String] {
        switch self {
        case .passwords: return ["passwords", "credentials", "logins", "keys", "accounts", "autofill"]
        case .protection: return ["protection", "privacy", "tracker", "security", "https", "shield", "cookies", "cache", "data", "storage", "website data"]
        case .downloads: return ["downloads", "files", "transfers"]
        case .history: return ["history", "recent", "visited", "sites", "logs"]
        case .permissions: return ["permissions", "camera", "microphone", "location", "notifications", "sites"]
        case .info: return ["info", "about", "diagnostics", "user agent", "profile", "debug", "version", "system"]
        case .extensions: return ["extensions", "plugins", "addons", "webextensions", "gallery", "store"]
        case .easel: return ["easel", "whiteboard", "canvas", "draw", "sketch", "board"]
        }
    }
}
