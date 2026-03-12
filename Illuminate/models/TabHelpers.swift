//
//  TabHelpers.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import AppKit
import Combine
import Foundation
import SwiftUI
import WebKit

struct TabState: Codable, Sendable {
    var currentURL: URL?
    var title: String?
    var scrollX: Double
    var scrollY: Double
    var zoomScale: Double
    var capturedAt: Date
}

struct TabTransferPayload: Codable, Sendable {
    var id: UUID
    var url: URL?
    var title: String?
    var isHibernated: Bool
    var state: TabState?
    var groupID: UUID?
}

struct SessionState: Codable, Sendable {
    let tabs: [TabTransferPayload]
    let tabGroups: [TabGroup]
    let activeTabID: UUID?
}

enum TabError: LocalizedError {
    case webViewOwnershipConflict

    var errorDescription: String? {
        switch self {
        case .webViewOwnershipConflict:
            return "This WKWebView is already owned by a different tab."
        }
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    func jpegData(compressionQuality: Float) -> Data? {
        guard let tiff = tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }

    func downsampled(toWidth targetWidth: CGFloat) -> NSImage {
        let scale  = targetWidth / size.width
        let target = NSSize(width: targetWidth, height: size.height * scale)

        return NSImage(size: target, flipped: false) { rect in
            self.draw(in: rect, from: .init(origin: .zero, size: self.size), operation: .copy, fraction: 1)
            return true
        }
    }
}

struct TabRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
