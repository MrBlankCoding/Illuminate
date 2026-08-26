//
//  PdfViewerIntegrationTests.swift
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
struct PdfViewerIntegrationTests {
    private let fileManager = FileManager.default
    private func makeTemporaryFile(name: String, contents: Data = Data("%PDF-1.4\n".utf8)) -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent(name)
        try? contents.write(to: url)
        return url
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

