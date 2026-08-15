//
//  ImageColorExtractorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import AppKit
import Foundation
import Testing
@testable import Illuminate

struct ImageColorExtractorTests {
    @Test func extractsPaletteAndDominantColorFromLocalImage() async throws {
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 20).fill()
        image.unlockFocus()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("illuminate-palette-\(UUID().uuidString).tiff")
        try image.tiffRepresentation?.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let palette = await ImageColorExtractor.shared.extractPalette(from: url, count: 3)
        let dominant = await ImageColorExtractor.shared.extractDominantColor(from: url)
        #expect(palette.isEmpty == false)
        #expect(dominant != nil)
    }

    @Test func missingOrInvalidImagesReturnEmptyResults() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).png")
        #expect(await ImageColorExtractor.shared.extractPalette(from: missing).isEmpty)
        #expect(await ImageColorExtractor.shared.extractDominantColor(from: missing) == nil)
    }
}
