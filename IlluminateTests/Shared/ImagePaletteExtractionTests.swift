//
//  ImagePaletteExtractionTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Testing
import Foundation
@testable import Illuminate
import AppKit

struct ImagePaletteExtractionTests {

    private func writePNG(colors: [NSColor], size: NSSize = NSSize(width: 40, height: 40)) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        let image = NSImage(size: size, flipped: false) { rect in
            let bandHeight = rect.height / CGFloat(max(colors.count, 1))
            for (index, color) in colors.enumerated() {
                color.setFill()
                rect.divided(atDistance: bandHeight * CGFloat(index + 1), from: .minYEdge).slice.fill()
            }
            return true
        }
        guard let data = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: data),
              let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode test image")
            return url
        }
        try png.write(to: url)
        return url
    }

    @Test func extractsPaletteFromLocalImage() async throws {
        let url = try writePNG(colors: [.systemBlue, .systemOrange, .systemGreen])
        defer { try? FileManager.default.removeItem(at: url) }

        let extractor = ImageColorExtractor.shared
        let palette = await extractor.extractPalette(from: url, count: 6)

        #expect(!palette.isEmpty)
        #expect(palette.count <= 6)

        let dominant = await extractor.extractDominantColor(from: url)
        #expect(dominant != nil)
    }

    @Test func corruptImageDataYieldsEmptyPalette() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? Data("not-an-image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let palette = await ImageColorExtractor.shared.extractPalette(from: url)
        #expect(palette.isEmpty)
    }

    @Test func unreachableRemoteURLYieldsEmptyPalette() async {
        let url = URL(string: "https://localhost:1/none.png")!
        let palette = await ImageColorExtractor.shared.extractPalette(from: url)
        #expect(palette.isEmpty)
    }
}
