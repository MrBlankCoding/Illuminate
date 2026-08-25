//
//  PdfViewerPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/20/26.
//

import AppKit
import PDFKit
import SwiftUI

// illuminate://pdf?src=<file-url>

struct PdfViewerPageView: View {
    let sourceURL: URL
    var accentColor: Color = .accentColor

    @State private var document: PDFDocument?
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if loadFailed {
                InternalPageEmptyState(
                    icon: "exclamationmark.triangle",
                    message: "This PDF could not be opened."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document {
                PDFKitView(document: document)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.primary.opacity(0.02))
        .task(id: sourceURL) {
            await loadDocument()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(sourceURL.lastPathComponent)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            if let document {
                Text(document.pageCount == 1 ? "1 page" : "\(document.pageCount) pages")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(sourceURL)
            } label: {
                Label("Open in Preview", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(InternalPageChipButtonStyle(color: accentColor))

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([sourceURL])
            } label: {
                Label("Reveal", systemImage: "folder")
            }
            .buttonStyle(InternalPageChipButtonStyle(color: .secondary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @MainActor
    private func loadDocument() async {
        loadFailed = false
        document = nil

        let startedAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if startedAccessing { sourceURL.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            AppLog.ui("PDF viewer failed to find file path=\(AppLog.sanitizedURL(sourceURL))")
            loadFailed = true
            return
        }

        let loaded = PDFDocument(url: sourceURL)
        await Task.yield()
        if let loaded {
            document = loaded
        } else {
            AppLog.ui("PDF viewer failed to load file path=\(AppLog.sanitizedURL(sourceURL))")
            loadFailed = true
        }
    }
}

private struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
            nsView.scaleFactor = nsView.scaleFactorForSizeToFit
        }
    }
}
