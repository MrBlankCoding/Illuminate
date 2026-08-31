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
    case pdf
    case easel

    static let urlScheme = "illuminate"
    private static let pdfSourceQueryKey = "src"
    static var suggestiblePages: [IlluminatePage] {
        allCases.filter { $0 != .pdf }
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

    static func pdfViewerURL(for fileURL: URL) -> URL? {
        guard isPDFFile(fileURL) else { return nil }
        var components = URLComponents(url: IlluminatePage.pdf.url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: pdfSourceQueryKey, value: fileURL.absoluteString)
        ]
        return components?.url
    }

    static func isPDFFile(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == "pdf"
    }

    func pdfSourceFileURL(from viewerURL: URL) -> URL? {
        guard
            self == .pdf,
            let components = URLComponents(url: viewerURL, resolvingAgainstBaseURL: false),
            let item = components.queryItems?.first(where: { $0.name == Self.pdfSourceQueryKey }),
            let value = item.value,
            let source = URL(string: value),
            Self.isPDFFile(source)
        else { return nil }
        return source
    }

    func displayTitle(for url: URL) -> String {
        if self == .pdf, let source = pdfSourceFileURL(from: url) {
            return source.lastPathComponent
        }
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
        case .pdf: return "PDF"
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
        case .pdf: return "PDF"
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
        case .pdf: return "doc.richtext.fill"
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
        case .pdf: return ["pdf", "viewer", "document"]
        case .easel: return ["easel", "whiteboard", "canvas", "draw", "sketch", "board"]
        }
    }
}
