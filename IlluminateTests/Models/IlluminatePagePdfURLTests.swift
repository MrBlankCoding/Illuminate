//
//  IlluminatePagePdfURLTests.swift
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
struct IlluminatePagePdfURLTests {
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
}
