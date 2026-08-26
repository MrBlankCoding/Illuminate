//
//  IlluminatePageRoutingTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct IlluminatePageRoutingTests {
        @Test func illuminateInfoPageRoutesCorrectly() {
        let url = URL(string: "illuminate://info")!
        let page = IlluminatePage(url: url)
        #expect(page == .info)
        #expect(page?.url == url)
    }

        @Test func pdfViewerURLRoundTripsSourceFile() throws {
        let file = URL(fileURLWithPath: "/tmp/Notes Report.pdf")
        let viewerURL = try #require(IlluminatePage.pdfViewerURL(for: file))

        #expect(IlluminatePage(url: viewerURL) == .pdf)
        let source = try #require(IlluminatePage.pdf.pdfSourceFileURL(from: viewerURL))
        #expect(source == file)
        #expect(IlluminatePage.pdf.displayTitle(for: viewerURL) == "Notes Report.pdf")
    }

        @Test func pdfViewerRejectsNonPDFFiles() {
        #expect(IlluminatePage.pdfViewerURL(for: URL(fileURLWithPath: "/tmp/notes.txt")) == nil)
        #expect(IlluminatePage.pdfViewerURL(for: URL(string: "https://example.com/doc.pdf")!) == nil)

        let remote = URL(string: "https://example.com/doc.pdf")!
        let viewerURL = URL(string: "illuminate://pdf?src=\(remote.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")
        #expect(viewerURL.flatMap { IlluminatePage.pdf.pdfSourceFileURL(from: $0) } == nil)
    }
}

