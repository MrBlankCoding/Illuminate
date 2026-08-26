//
//  TabHelpersTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Testing
import Foundation
@testable import Illuminate
import AppKit

struct TabHelpersTests {

    @Test func sessionStateCodableRoundTrip() throws {
        let payload = SessionState(
            tabIDs: [UUID()],
            tabs: [TabTransferPayload(id: UUID(), url: URL(string: "https://example.com")!, title: "Example")],
            activeTabID: UUID()
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SessionState.self, from: data)

        #expect(decoded.tabIDs == payload.tabIDs)
        #expect(decoded.activeTabID == payload.activeTabID)
        #expect(decoded.tabs?.first?.title == "Example")
    }

    @Test func optionalFieldsDecodeAsNil() throws {
        let json = #"{"tabIDs":null,"tabs":null,"activeTabID":null}"#
        let decoded = try JSONDecoder().decode(SessionState.self, from: Data(json.utf8))
        #expect(decoded.tabIDs == nil)
        #expect(decoded.tabs == nil)
        #expect(decoded.activeTabID == nil)
    }

    @Test func webViewOwnershipConflictHasFriendlyMessage() {
        let error = TabError.webViewOwnershipConflict
        #expect(error.errorDescription == "This WKWebView is already owned by a different tab.")
    }

    @Test func imageEncodingProducesFormats() throws {
        let image = NSImage(size: NSSize(width: 32, height: 16), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }

        let png = try #require(image.pngData())
        #expect(png.count > 0)

        let jpeg = try #require(image.jpegData(compressionQuality: 0.5))
        #expect(jpeg.count > 0)
    }

    @Test func downsamplePreservesAspectRatio() {
        let original = NSImage(size: NSSize(width: 200, height: 100), flipped: false) { rect in
            NSColor.blue.setFill()
            rect.fill()
            return true
        }

        let downsampled = original.downsampled(toWidth: 100)
        #expect(abs(downsampled.size.width - 100) <= 1)
        #expect(abs(downsampled.size.height - 50) <= 1)
    }
}
