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

    @State private var controller = PDFViewerController()
    @State private var loadFailed = false
    @State private var isLoading = true
    @State private var sidebarMode: SidebarMode = .none
    @State private var showSearchBar = false
    @State private var searchQuery = ""
    @State private var pageJumpText = ""
    @State private var passwordInput = ""
    @State private var passwordError = false
    @FocusState private var searchFieldFocused: Bool

    enum SidebarMode {
        case none, thumbnails, outline
    }

    var body: some View {
        HStack(spacing: 0) {
            if sidebarMode != .none, !loadFailed, !controller.isLocked {
                sidebar
                Divider()
            }

            VStack(spacing: 0) {
                if !loadFailed {
                    header
                    Divider()

                    if showSearchBar, !controller.isLocked {
                        searchBar
                        Divider()
                    }
                }

                ZStack {
                    if loadFailed {
                        InternalPageEmptyState(
                            icon: "exclamationmark.triangle",
                            message: "This PDF could not be opened."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if controller.isLocked {
                        passwordPrompt
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        GeometryReader { geometry in
                            PDFKitView(controller: controller)
                                .onChange(of: geometry.size.width) { _, newWidth in
                                    controller.containerWidthChanged(to: newWidth)
                                }
                                .onAppear {
                                    controller.containerWidthChanged(to: geometry.size.width)
                                }
                        }

                        if isLoading {
                            loadingOverlay
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: sourceURL) {
            await loadDocument()
        }
        .onChange(of: controller.currentPageIndex) { _, newIndex in
            pageJumpText = "\(newIndex + 1)"
        }
        .onChange(of: controller.pageCount) { _, _ in
            pageJumpText = "\(controller.currentPageIndex + 1)"
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            headerButton(sidebarMode != .none ? "sidebar.leading" : "sidebar.left", "Toggle Sidebar") {
                withAnimation(.easeOut(duration: 0.15)) {
                    sidebarMode = (sidebarMode == .none) ? .thumbnails : .none
                }
            }

            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(sourceURL.lastPathComponent)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(sourceURL.path)

            if controller.pageCount > 0 {
                Text(pageStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                headerButton("chevron.left", "Previous Page") {
                    controller.goToPreviousPage()
                }
                .disabled(!controller.canGoToPreviousPage)

                HStack(spacing: 3) {
                    TextField("", text: $pageJumpText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 24)
                        .onSubmit { jumpToPage() }

                    Text("/ \(max(controller.pageCount, 1))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(minWidth: 56)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                headerButton("chevron.right", "Next Page") {
                    controller.goToNextPage()
                }
                .disabled(!controller.canGoToNextPage)
            }

            divider

            HStack(spacing: 4) {
                headerButton("minus.magnifyingglass", "Zoom Out") {
                    controller.zoomOut()
                }
                .disabled(!controller.canZoomOut)

                Menu {
                    ForEach([50, 75, 100, 125, 150, 200, 300, 400], id: \.self) { percent in
                        Button("\(percent)%") { controller.setZoomPercent(percent) }
                    }
                } label: {
                    Text(controller.zoomPercentText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 40)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                headerButton("plus.magnifyingglass", "Zoom In") {
                    controller.zoomIn()
                }
                .disabled(!controller.canZoomIn)

                headerButton("arrow.left.and.right.righttriangle.left.righttriangle.right.fill", "Fit Width") {
                    controller.fitWidth()
                }
            }

            divider

            HStack(spacing: 4) {
                headerButton("rotate.left", "Rotate Left") {
                    controller.rotateCurrentPage(by: -90)
                }
                headerButton("rotate.right", "Rotate Right") {
                    controller.rotateCurrentPage(by: 90)
                }
                headerButton(controller.isSinglePageMode ? "square.stack" : "square", controller.isSinglePageMode ? "Continuous Scroll" : "Single Page") {
                    controller.toggleDisplayMode()
                }
            }

            divider

            headerButton("magnifyingglass", "Find in Document") {
                withAnimation(.easeOut(duration: 0.12)) {
                    showSearchBar.toggle()
                }
                if showSearchBar {
                    searchFieldFocused = true
                } else {
                    searchQuery = ""
                    controller.clearSearch()
                }
            }
            .keyboardShortcut("f", modifiers: .command)

            headerButton("printer", "Print") {
                controller.printDocument()
            }
            .keyboardShortcut("p", modifiers: .command)

            Button {
                FinderReveal.open(sourceURL)
            } label: {
                Label("Open in Preview", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(InternalPageChipButtonStyle(color: accentColor))

            Button {
                FinderReveal.reveal(sourceURL)
            } label: {
                Label("Reveal", systemImage: "folder")
            }
            .buttonStyle(InternalPageChipButtonStyle(color: .secondary))

            headerButton("arrow.up.left.and.arrow.down.right", "Toggle Full Screen") {
                toggleFullScreen()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 16)
    }

    private var pageStatusText: String {
        controller.pageCount == 1 ? "1 page" : "\(controller.pageCount) pages"
    }

    private func toggleFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    private func jumpToPage() {
        guard let value = Int(pageJumpText) else {
            pageJumpText = "\(controller.currentPageIndex + 1)"
            return
        }
        let clamped = min(max(value, 1), max(controller.pageCount, 1))
        controller.goToPageIndex(clamped - 1)
        pageJumpText = "\(clamped)"
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("Find in document", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFieldFocused)
                .onSubmit { controller.goToNextMatch() }
                .onChange(of: searchQuery) { _, newValue in
                    controller.performSearch(newValue)
                }

            if !controller.searchMatches.isEmpty {
                Text("\(controller.currentMatchIndex + 1) of \(controller.searchMatches.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if !searchQuery.isEmpty {
                Text("No results")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            headerButton("chevron.up", "Previous Match") {
                controller.goToPreviousMatch()
            }
            .disabled(controller.searchMatches.isEmpty)

            headerButton("chevron.down", "Next Match") {
                controller.goToNextMatch()
            }
            .disabled(controller.searchMatches.isEmpty)

            headerButton("xmark", "Close Search") {
                showSearchBar = false
                searchQuery = ""
                controller.clearSearch()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sidebarMode) {
                Image(systemName: "square.grid.2x2").tag(SidebarMode.thumbnails)
                Image(systemName: "list.bullet.indent").tag(SidebarMode.outline)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch sidebarMode {
            case .thumbnails:
                thumbnailList
            case .outline:
                outlineList
            case .none:
                EmptyView()
            }
        }
        .frame(width: 200)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var thumbnailList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(0..<max(controller.pageCount, 0), id: \.self) { index in
                        VStack(spacing: 4) {
                            Group {
                                if let image = controller.thumbnailCache[index] {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                        .aspectRatio(0.77, contentMode: .fit)
                                        .overlay(ProgressView().controlSize(.small))
                                }
                            }
                            .frame(width: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .shadow(
                                color: .black.opacity(index == controller.currentPageIndex ? 0.25 : 0.1),
                                radius: index == controller.currentPageIndex ? 3 : 1, y: 1
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(
                                        index == controller.currentPageIndex ? accentColor : Color.primary.opacity(0.15),
                                        lineWidth: index == controller.currentPageIndex ? 2 : 1
                                    )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.12)) {
                                    controller.goToPageIndex(index)
                                }
                            }
                            .hoverCursor(.pointingHand)
                            .task {
                                controller.requestThumbnail(for: index)
                            }

                            Text("\(index + 1)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .id(index)
                    }
                }
                .padding(12)
            }
            .onChange(of: controller.currentPageIndex) { _, newIndex in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private var outlineList: some View {
        ScrollView {
            if let root = controller.outlineRoot, root.numberOfChildren > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<root.numberOfChildren, id: \.self) { i in
                        if let child = root.child(at: i) {
                            OutlineRowView(outline: child, depth: 0) { destination in
                                controller.goTo(destination: destination)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                InternalPageEmptyState(icon: "list.bullet", message: "No outline available.")
                    .padding(.top, 40)
            }
        }
    }

    private var passwordPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.doc")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("This document is password protected")
                .font(.system(size: 13, weight: .medium))

            SecureField("Password", text: $passwordInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit(attemptUnlock)

            if passwordError {
                Text("Incorrect password. Try again.")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            Button("Unlock", action: attemptUnlock)
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(passwordInput.isEmpty)
        }
        .padding(24)
    }

    private func attemptUnlock() {
        guard !passwordInput.isEmpty else { return }
        if controller.unlock(password: passwordInput) {
            passwordError = false
            passwordInput = ""
        } else {
            passwordError = true
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.6)
            ProgressView("Loading document…")
                .controlSize(.small)
        }
        .transition(.opacity)
    }

    private func headerButton(_ systemImage: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.75))
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .hoverCursor(.pointingHand)
        .help(label)
        .accessibilityLabel(label)
    }

    @MainActor
    private func loadDocument() async {
        loadFailed = false
        isLoading = true
        defer { isLoading = false }

        let url = sourceURL
        let loadedDocument: PDFDocument? = await Task.detached(priority: .userInitiated) { () -> PDFDocument? in
            url.withSecurityScopedAccess {
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                return PDFDocument(url: url)
            }
        }.value

        if let document = loadedDocument {
            controller.setDocument(document)
            pageJumpText = "1"
        } else {
            loadFailed = true
        }
    }
}
