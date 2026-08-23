//
//  TabHelpers.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import AppKit
import Foundation
import SwiftUI

public struct TabTransferPayload: Codable, Sendable {
    var id: UUID
    var url: URL?
    var title: String?
}

struct SessionState: Codable, Sendable {
    var tabIDs: [UUID]?
    var tabs: [TabTransferPayload]?
    var activeTabID: UUID?
}

struct TabMetadataPayload: Codable, Sendable {
    var url: URL?
    var title: String?
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
    private func bitmapRepresentation() -> NSBitmapImageRep? {
        var proposedRect = NSRect(origin: .zero, size: size)
        if let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            return NSBitmapImageRep(cgImage: cgImage)
        }

        guard size.width > 0, size.height > 0 else { return nil }

        let width = Int(size.width)
        let height = Int(size.height)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return nil
        }

        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    func pngData() -> Data? {
        guard let rep = bitmapRepresentation() else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    func jpegData(compressionQuality: Float) -> Data? {
        guard let rep = bitmapRepresentation() else { return nil }
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


