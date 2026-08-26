//
//  PdfViewerController.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import Combine
import PDFKit
import SwiftUI

@MainActor
final class PDFViewerController: ObservableObject {
    static let minScale: CGFloat = 0.1
    static let maxScale: CGFloat = 8
    static let zoomStep: CGFloat = 1.2
    static let fitPadding: CGFloat = 32

    @Published private(set) var pageCount = 0
    @Published private(set) var currentPageIndex = 0
    @Published private(set) var zoomPercent = 100
    @Published private(set) var isLocked = false
    @Published private(set) var isSinglePageMode = false
    @Published private(set) var thumbnailCache: [Int: NSImage] = [:]
    @Published private(set) var outlineRoot: PDFOutline?
    @Published private(set) var searchMatches: [PDFSelection] = []
    @Published private(set) var currentMatchIndex: Int = -1

    let pdfView = PDFView()

    private(set) var document: PDFDocument?
    private var containerWidth: CGFloat = 0
    private var lastFitTargetWidth: CGFloat = 0
    private var pendingThumbnails: Set<Int> = []

    var zoomPercentText: String { "\(zoomPercent)%" }
    var canZoomIn: Bool { document != nil && pdfView.scaleFactor < Self.maxScale }
    var canZoomOut: Bool { document != nil && pdfView.scaleFactor > Self.minScale }
    var canGoToPreviousPage: Bool { currentPageIndex > 0 }
    var canGoToNextPage: Bool { currentPageIndex < pageCount - 1 }

    init() {
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .clear
        pdfView.wantsLayer = true
        pdfView.minScaleFactor = Self.minScale
        pdfView.maxScaleFactor = Self.maxScale

        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(pdfScaleDidChange),
            name: .PDFViewScaleChanged, object: pdfView
        )
        center.addObserver(
            self, selector: #selector(pdfPageDidChange),
            name: .PDFViewPageChanged, object: pdfView
        )
    }

    @objc private func pdfScaleDidChange() {
        refreshZoomPercent()
    }

    @objc private func pdfPageDidChange() {
        refreshCurrentPageIndex()
    }

    func setDocument(_ newDocument: PDFDocument?) {
        document = newDocument
        thumbnailCache.removeAll()
        pendingThumbnails.removeAll()
        searchMatches = []
        currentMatchIndex = -1
        currentPageIndex = 0

        let locked = newDocument?.isLocked ?? false
        isLocked = locked

        pageCount = newDocument?.pageCount ?? 0

        if locked {
            outlineRoot = nil
            pdfView.document = nil
        } else {
            pdfView.document = newDocument
            outlineRoot = newDocument?.outlineRoot
            DispatchQueue.main.async { [weak self] in
                self?.fitWidth()
            }
        }
    }

    func unlock(password: String) -> Bool {
        guard let document else { return false }
        let success = document.unlock(withPassword: password)
        guard success else { return false }

        isLocked = false
        pdfView.document = document
        pageCount = document.pageCount
        outlineRoot = document.outlineRoot
        DispatchQueue.main.async { [weak self] in
            self?.fitWidth()
        }
        return true
    }

    func requestThumbnail(for pageIndex: Int) {
        guard thumbnailCache[pageIndex] == nil, !pendingThumbnails.contains(pageIndex) else { return }
        guard let document, pageIndex >= 0, pageIndex < document.pageCount else { return }
        pendingThumbnails.insert(pageIndex)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let page = document.page(at: pageIndex) else { return }
            let image = page.thumbnail(of: CGSize(width: 200, height: 260), for: .mediaBox)
            await MainActor.run {
                self?.thumbnailCache[pageIndex] = image
                self?.pendingThumbnails.remove(pageIndex)
            }
        }
    }

    func containerWidthChanged(to width: CGFloat) {
        let isFirstLayout = containerWidth == 0 && width > 0
        containerWidth = width
        if isFirstLayout || abs(width - lastFitTargetWidth) > 0.5 {
            fitWidth()
        }
    }

    func fitWidth() {
        guard let pageWidth = basePageWidth, containerWidth > Self.fitPadding else { return }
        let target = (containerWidth - Self.fitPadding) / pageWidth
        applyScale(target)
        lastFitTargetWidth = containerWidth
    }

    func zoomIn() {
        applyScale(pdfView.scaleFactor * Self.zoomStep)
    }

    func zoomOut() {
        applyScale(pdfView.scaleFactor / Self.zoomStep)
    }

    func setZoomPercent(_ percent: Int) {
        guard let basePageWidth, containerWidth > Self.fitPadding, basePageWidth > 0 else { return }
        let base = (containerWidth - Self.fitPadding) / basePageWidth
        guard base > 0 else { return }
        applyScale(base * CGFloat(percent) / 100)
    }

    func goToNextPage() {
        goToPageIndex(currentPageIndex + 1)
    }

    func goToPreviousPage() {
        goToPageIndex(currentPageIndex - 1)
    }

    func goToPageIndex(_ index: Int) {
        guard let document,
              index >= 0, index < document.pageCount,
              let page = document.page(at: index) else { return }
        pdfView.go(to: PDFDestination(page: page, at: .zero))
        currentPageIndex = index
    }

    func goTo(destination: PDFDestination) {
        pdfView.go(to: destination)
        if let page = destination.page, let document {
            currentPageIndex = document.index(for: page)
        }
    }

    func rotateCurrentPage(by degrees: Int) {
        guard let page = document?.page(at: currentPageIndex) else { return }
        let newRotation = (page.rotation + degrees) % 360
        page.rotation = newRotation < 0 ? newRotation + 360 : newRotation
        pdfView.layoutDocumentView()
        thumbnailCache[currentPageIndex] = nil
        requestThumbnail(for: currentPageIndex)
    }

    func toggleDisplayMode() {
        isSinglePageMode.toggle()
        pdfView.displayMode = isSinglePageMode ? .singlePage : .singlePageContinuous
        goToPageIndex(currentPageIndex)
    }

    func performSearch(_ query: String) {
        searchMatches = []
        currentMatchIndex = -1
        pdfView.clearSelection()
        guard let document, !query.isEmpty else { return }

        let selections = document.findString(query, withOptions: [.caseInsensitive])
        searchMatches = selections
        if !selections.isEmpty {
            currentMatchIndex = 0
            highlightCurrentMatch()
        }
    }

    func goToNextMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        highlightCurrentMatch()
    }

    func goToPreviousMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        highlightCurrentMatch()
    }

    func clearSearch() {
        searchMatches = []
        currentMatchIndex = -1
        pdfView.clearSelection()
    }

    private func highlightCurrentMatch() {
        guard currentMatchIndex >= 0, currentMatchIndex < searchMatches.count else { return }
        let selection = searchMatches[currentMatchIndex]
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.scrollSelectionToVisible(nil)
        if let page = selection.pages.first, let document {
            currentPageIndex = document.index(for: page)
        }
    }

    func printDocument() {
        guard let document,
              let printOperation = document.printOperation(
                for: NSPrintInfo.shared,
                scalingMode: .pageScaleToFit,
                autoRotate: true
              ) else { return }
        printOperation.run()
    }

    private var basePageWidth: CGFloat? {
        guard let page = pdfView.currentPage ?? document?.page(at: 0),
              page.bounds(for: .mediaBox).width > 0 else { return nil }
        return page.bounds(for: .mediaBox).width
    }

    private func applyScale(_ scale: CGFloat) {
        guard document != nil else { return }
        pdfView.scaleFactor = min(max(scale, Self.minScale), Self.maxScale)
        refreshZoomPercent()
    }

    private func refreshZoomPercent() {
        guard let basePageWidth, containerWidth > Self.fitPadding, basePageWidth > 0 else { return }
        let base = (containerWidth - Self.fitPadding) / basePageWidth
        guard base > 0 else { return }
        zoomPercent = Int((pdfView.scaleFactor / base * 100).rounded())
    }

    private func refreshCurrentPageIndex() {
        guard let document, let current = pdfView.currentPage else { return }
        currentPageIndex = document.index(for: current)
    }
}


