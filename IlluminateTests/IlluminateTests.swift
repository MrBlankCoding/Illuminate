//
//  IlluminateTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/8/26.
//

import Testing
import AppKit
import Foundation
import SwiftUI
@testable import Illuminate

// test for cacheing images or something.

struct IlluminateTests {

    @Test func testTabAssetPersistence() async throws {
        let tabID = UUID()
        let image = await MainActor.run {
            let size = NSSize(width: 10, height: 10)
            let img = NSImage(size: size)
            img.lockFocus()
            NSColor.red.set()
            NSRect(origin: .zero, size: size).fill()
            img.unlockFocus()
            return img
        }

        let base = FileManager.default
            .illuminateAppSupportDirectory()
            .appendingPathComponent("TabAssets", isDirectory: true)
        let tabFolder = base.appendingPathComponent(tabID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tabFolder, withIntermediateDirectories: true)

        let faviconURL = tabFolder.appendingPathComponent("favicon.png")
        let snapshotURL = tabFolder.appendingPathComponent("snapshot.jpg")
        try image.pngData()?.write(to: faviconURL)
        try image.jpegData(compressionQuality: 0.7)?.write(to: snapshotURL)

        #expect(FileManager.default.fileExists(atPath: tabFolder.appendingPathComponent("favicon.png").path))
        #expect(FileManager.default.fileExists(atPath: tabFolder.appendingPathComponent("snapshot.jpg").path))
        
        let restoredTab = await MainActor.run {
            Tab(id: tabID, url: URL(string: "https://google.com"), title: "Google")
        }
        
        await MainActor.run {
            restoredTab.loadAssets()
        }
        
        // Wait for detached task in loadAssets() to complete
        try await Task.sleep(for: .milliseconds(100))
        
        await MainActor.run {
            #expect(restoredTab.favicon != nil)
            #expect(restoredTab.snapshot != nil)
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: tabFolder)
    }

}
