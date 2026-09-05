//
//  AppFileOpeningQueueTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct AppFileOpeningQueueTests {
    private let fileManager = FileManager.default
    private func makeTemporaryFile(name: String, contents: Data = Data("%PDF-1.4\n".utf8)) -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent(name)
        try? contents.write(to: url)
        return url
    }

        @Test func drainingPDFDoesNotCreateTab() throws {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let initialCount = tabManager.tabs.count

        let file = makeTemporaryFile(name: "Quarterly Report-\(UUID().uuidString).pdf")

        AppFileOpening.shared.enqueue(file)
        AppFileOpening.shared.drain(into: tabManager)

        // PDF is opened externally via NSWorkspace, not a tab
        #expect(tabManager.tabs.count == initialCount)
    }

    @Test func drainingNonPDFKeepsOriginalFileURL() {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let initialCount = tabManager.tabs.count

        let file = URL(fileURLWithPath: "/tmp/plain-\(UUID().uuidString).txt")

        AppFileOpening.shared.enqueue(file)
        AppFileOpening.shared.drain(into: tabManager)

        #expect(tabManager.tabs.count == initialCount + 1)
        #expect(tabManager.tabs.last?.url == file.standardizedFileURL)
    }

        @Test func enqueueIgnoresRemoteURLs() {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let initialCount = tabManager.tabs.count

        AppFileOpening.shared.enqueue(URL(string: "https://example.com/doc.pdf")!)
        AppFileOpening.shared.drain(into: tabManager)

        #expect(tabManager.tabs.count == initialCount)
    }

        @Test func enqueueDeduplicatesPendingFiles() throws {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let initialCount = tabManager.tabs.count

        let file = makeTemporaryFile(name: "Duplicate-\(UUID().uuidString).pdf")

        AppFileOpening.shared.enqueue(file)
        AppFileOpening.shared.enqueue(file)
        AppFileOpening.shared.drain(into: tabManager)

        // PDF is opened externally, not a tab
        #expect(tabManager.tabs.count == initialCount)
    }

        @Test func needsBrowserWindowFlagRoundTrips() {
        AppFileOpening.shared.markNeedsBrowserWindow()
        #expect(AppFileOpening.shared.needsBrowserWindow)

        AppFileOpening.shared.clearNeedsBrowserWindow()
        #expect(!AppFileOpening.shared.needsBrowserWindow)
    }
}
