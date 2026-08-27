//
//  FinderReveal.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/20/26.
//

import AppKit
import Foundation

@MainActor
enum FinderReveal {
    static func reveal(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) {
                NSWorkspace.shared.open(parent)
            }
            return
        }

        url.withSecurityScopedAccess {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    static func open(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        _ = url.withSecurityScopedAccess {
            NSWorkspace.shared.open(url)
        }
    }
}
