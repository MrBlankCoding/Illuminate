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

        @Test func drainingPDFCreatesViewerTabTitledByFilename() throws {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let initialCount = tabManager.tabs.count

        let file = makeTemporaryFile(name: "Quarterly Report-\(UUID().uuidString).pdf")
        let viewerURL = try #require(IlluminatePage.pdfViewerURL(for: file))

        AppFileOpening.shared.enqueue(file)
        AppFileOpening.shared.drain(into: tabManager)

        #expect(tabManager.tabs.count == initialCount + 1)
        let tab = tabManager.tabs.last
        #expect(tab?.url == viewerURL)
        #expect(tab?.title == file.lastPathComponent)

        AppFileOpening.shared.drain(into: tabManager) // no double-open
        #expect(tabManager.tabs.count == initialCount + 1)
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
        let viewerURL = try #require(IlluminatePage.pdfViewerURL(for: file))

        AppFileOpening.shared.enqueue(file)
        AppFileOpening.shared.enqueue(file)
        AppFileOpening.shared.drain(into: tabManager)

        let createdTabs = tabManager.tabs.dropFirst(initialCount).filter { $0.url == viewerURL }
        #expect(createdTabs.count == 1)
    }

        @Test func needsBrowserWindowFlagRoundTrips() {
        AppFileOpening.shared.markNeedsBrowserWindow()
        #expect(AppFileOpening.shared.needsBrowserWindow)

        AppFileOpening.shared.clearNeedsBrowserWindow()
        #expect(!AppFileOpening.shared.needsBrowserWindow)
    }
}
