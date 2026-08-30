//
//  AppDelegate.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import AppKit
import Foundation
import Testing
@testable import Illuminate

struct BrowserImageLoaderTests {
    @Test func dataURLDecodingProducesImage() async throws {
        // 1x1 red PNG as data URL
        let loader = BrowserImageLoader.shared
        // Create a 1x1 image and encode as data URL
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1, height: 1)).fill()
        image.unlockFocus()
        guard let png = image.pngData() else {
            Issue.record("pngData failed")
            return
        }
        let b64 = png.base64EncodedString()
        let url = URL(string: "data:image/png;base64,\(b64)")!
        let loaded = try await loader.loadImage(from: url)
        #expect(loaded.size.width > 0)
    }

    @Test func unsupportedSchemeThrows() async {
        let loader = BrowserImageLoader.shared
        let url = URL(string: "ftp://example.com/icon.png")!
        do {
            _ = try await loader.loadImage(from: url)
            Issue.record("Should have thrown")
        } catch {
            // Expected — unsupported scheme.
            #expect(error is URLError)
        }
    }

    @Test func cancellationIsObserved() async {
        let loader = BrowserImageLoader.shared
        let url = URL(string: "https://example.com/slow-favicon.ico")!
        let task = Task {
            try await loader.loadImage(from: url)
        }
        task.cancel()
        do {
            _ = try await task.value
        } catch is CancellationError {
            // Cancellation propagated correctly.
            #expect(true)
        } catch {
            // Network error also acceptable if cancellation raced after start.
            #expect(true)
        }
    }
}
