//
//  FaviconLoader.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26
//

import AppKit
import Foundation
import Nuke

final class FaviconLoader: Sendable {
    static let shared = FaviconLoader()

    private let imageLoader: BrowserImageLoader
    private let negativeCache = NegativeCache()

    init(imageLoader: BrowserImageLoader = .shared) {
        self.imageLoader = imageLoader
    }

    func loadFavicon(
        for pageURL: URL?,
        declaredFaviconURL: URL? = nil,
        priority: ImageRequest.Priority = .normal
    ) async -> NSImage? {
        if let declared = declaredFaviconURL {
            if let img = await loadFavicon(from: declared, priority: priority) { return img }
        }
        guard let fallback = Self.defaultFaviconURL(for: pageURL) else { return nil }
        if declaredFaviconURL == fallback { return nil }
        return await loadFavicon(from: fallback, priority: priority)
    }

    func loadFavicon(
        from url: URL,
        priority: ImageRequest.Priority = .normal
    ) async -> NSImage? {
        if url.scheme?.lowercased() == "data" {
            return try? await imageLoader.loadImage(from: url, priority: priority)
        }

        guard Self.isSupportedScheme(url) else { return nil }
        let key = url.absoluteString
        if await negativeCache.contains(key) { return nil }

        do {
            try Task.checkCancellation()
            let image = try await imageLoader.loadImage(from: url, priority: priority)
            await negativeCache.remove(key)
            return image
        } catch is CancellationError {
            return nil
        } catch {
            await negativeCache.insert(key)
            return nil
        }
    }

    static func defaultFaviconURL(for pageURL: URL?) -> URL? {
        guard let pageURL,
              let scheme = pageURL.scheme?.lowercased(),
              let host = pageURL.host,
              ["http", "https", "webkit-extension"].contains(scheme) else { return nil }
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        c.path = "/favicon.ico"
        return c.url
    }

    static func resolveFaviconURL(from rawValue: String, pageURL: URL?) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let resolved: URL?
        if trimmed.hasPrefix("data:") {
            resolved = URL(string: trimmed)
        } else if let pageURL {
            resolved = URL(string: trimmed, relativeTo: pageURL)?.absoluteURL
        } else {
            resolved = URL(string: trimmed)
        }
        guard let resolved, isSupportedScheme(resolved) else { return nil }
        return resolved
    }

    private static func isSupportedScheme(_ url: URL) -> Bool {
        guard let s = url.scheme?.lowercased() else { return false }
        return ["http", "https", "data"].contains(s)
    }

    private actor NegativeCache {
        private var entries: [String: Date] = [:]
        private let ttl: TimeInterval = 5 * 60

        func contains(_ key: String) -> Bool {
            guard let date = entries[key] else { return false }
            if Date().timeIntervalSince(date) > ttl {
                entries.removeValue(forKey: key)
                return false
            }
            return true
        }
        func insert(_ key: String) { entries[key] = Date() }
        func remove(_ key: String) { entries.removeValue(forKey: key) }
    }
}
