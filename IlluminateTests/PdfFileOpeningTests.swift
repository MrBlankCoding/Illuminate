//
//  PdfFileOpeningTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/20/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct PdfFileOpeningTests {
    private let fileManager = FileManager.default

    private func makeTemporaryFile(name: String, contents: Data = Data("%PDF-1.4\n".utf8)) -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent(name)
        try? contents.write(to: url)
        return url
    }

    @Test func localPDFBuildsViewerURL() throws {
        let file = makeTemporaryFile(name: "Report-\(UUID().uuidString).pdf")
        let viewerURL = try #require(IlluminatePage.pdfViewerURL(for: file))

        #expect(IlluminatePage(url: viewerURL) == .pdf)
        #expect(try #require(IlluminatePage.pdf.pdfSourceFileURL(from: viewerURL)) == file)
    }

    @Test func nonPDFFilesDoNotGetViewerURLs() {
        let text = URL(fileURLWithPath: "/tmp/notes-\(UUID().uuidString).txt")
        let html = URL(fileURLWithPath: "/tmp/page-\(UUID().uuidString).html")

        #expect(IlluminatePage.pdfViewerURL(for: text) == nil)
        #expect(IlluminatePage.pdfViewerURL(for: html) == nil)
        #expect(!IlluminatePage.isPDFFile(text))
    }

    @Test func viewerURLRejectsRemoteSources() {
        let remote = URL(string: "https://example.com/document.pdf")!
        let encoded = remote.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let viewerURL = URL(string: "illuminate://pdf?src=\(encoded)")!

        #expect(IlluminatePage.pdf.pdfSourceFileURL(from: viewerURL) == nil)
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

    @Test func addressBarShowsFilePathForPDFPages() throws {
        let file = makeTemporaryFile(name: "Manual-\(UUID().uuidString).pdf")
        let viewerURL = try #require(IlluminatePage.pdfViewerURL(for: file))

        #expect(ContentViewModel.addressBarDisplayText(for: viewerURL) == file.path)
        #expect(ContentViewModel.addressBarDisplayText(for: URL(string: "https://example.com")!) == "https://example.com")
        #expect(ContentViewModel.addressBarDisplayText(for: nil) == "")
    }

    @Test func loadingViewerURLSetsFilenameAsTabTitle() throws {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let tab = try #require(tabManager.activeTab)

        let file = makeTemporaryFile(name: "Spec-\(UUID().uuidString).pdf")
        let viewerURL = try #require(IlluminatePage.pdfViewerURL(for: file))

        tab.load(url: viewerURL)

        #expect(tab.url == viewerURL)
        #expect(tab.title == file.lastPathComponent)
    }
}
