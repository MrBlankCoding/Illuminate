//
//  TabVisualState.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import Foundation
import SwiftUI
import WebKit

@MainActor
extension TabManager {
    func hydrateVisualState(for tab: Tab) {
        tab.loadAssets()

        if let special = specialFavicon(for: tab.url) {
            tab.favicon = special
            return
        }

        guard tab.favicon == nil, let faviconURL = defaultFaviconURL(for: tab.url) else { return }
        Task(priority: .background) { [weak tab, faviconCache] in
            guard let image = await faviconCache.imageIncludingDisk(for: faviconURL) else { return }
            await MainActor.run {
                guard let tab, tab.favicon == nil else { return }
                tab.favicon = image
            }
        }
    }

    func defaultFaviconURL(for pageURL: URL?) -> URL? {
        guard
            let pageURL,
            let scheme = pageURL.scheme?.lowercased(),
            let host   = pageURL.host,
            scheme == "http" || scheme == "https" || scheme == "webkit-extension"
        else { return nil }

        var components    = URLComponents()
        components.scheme = scheme
        components.host   = host
        components.path   = "/favicon.ico"
        return components.url
    }

    func specialFavicon(for pageURL: URL?) -> NSImage? {
        guard pageURL?.scheme?.lowercased() == "illuminate" else { return nil }
        switch pageURL?.host?.lowercased() {
        case "passwords":
            return NSImage(systemSymbolName: "key.fill", accessibilityDescription: "Passwords")
        case "protection":
            return NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "Protection")
        case "downloads":
            return NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Downloads")
        case "history":
            return NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "History")
        default:
            return nil
        }
    }

    func removeTabAssets(for id: UUID) {
        let folder = tabAssetsBaseURL
            .appendingPathComponent("TabAssets", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)

        Task.detached(priority: .utility) {
            do {
                try FileManager.default.removeItem(at: folder)
            } catch {
                let nsError = error as NSError
                let isMissingFile = nsError.domain == NSCocoaErrorDomain
                    && nsError.code == NSFileNoSuchFileError
                guard !isMissingFile else { return }
                AppLog.error("Could not remove tab assets for \(id.uuidString)", error: error)
            }
        }
    }

    func updateThemeFromBackground(applyTheme: Bool) {
        backgroundThemeTask?.cancel()

        guard !backgroundImageURL.isEmpty, let url = URL(string: backgroundImageURL) else {
            backgroundImagePalette = []
            return
        }

        let expectedURLString = backgroundImageURL
        backgroundThemeTask = Task { [weak self] in
            let palette = await ImageColorExtractor.shared.extractPalette(from: url)
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                guard self.backgroundImageURL == expectedURLString else { return }

                withAnimation(.easeInOut(duration: 0.35)) {
                    self.backgroundImagePalette = palette
                    if applyTheme, let first = palette.first {
                        self.windowThemeColor = first
                        
                        // Update the advanced theme model as well
                        if let firstIdx = self.theme.colors.indices.first {
                            let hsl = first.resolvedHSL
                            self.theme.colors[firstIdx].hue = hsl.h
                            self.theme.colors[firstIdx].saturation = hsl.s
                            self.theme.colors[firstIdx].lightness = hsl.l
                            self.theme.colors[firstIdx].position = ThemeColorMath.colorToPoint(hue: hsl.h, saturation: hsl.s)
                        }
                    }
                }
            }
        }
    }
}
