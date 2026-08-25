//
//  WebView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import SwiftUI
import WebKit

struct WebView: View {
    @ObservedObject var tab: Tab

    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var webKitManager: WebKitManager
    @EnvironmentObject private var passwordService: PasswordService
    @EnvironmentObject private var trackerBlockingService: TrackerBlockingService
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var websitePermissionService: WebsitePermissionService
    @EnvironmentObject private var canvasFingerprintingService: CanvasFingerprintingService

    var body: some View {
        ZStack {
            if let url = tab.url {
                content(for: url)
            } else {
                NewTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            contextMenuContent(for: tab.url)
        }
    }

    @ViewBuilder
    private func content(for url: URL) -> some View {
        switch IlluminatePage(url: url) {
        case .passwords:
            PasswordsPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        case .protection:
            ProtectionPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        case .downloads:
            DownloadsPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        case .history:
            HistoryPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        case .permissions:
            PermissionsPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        case .info:
            InfoPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        case .extensions:
            ExtensionSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        case .pdf:
            if let sourceURL = IlluminatePage.pdf.pdfSourceFileURL(from: url) {
                PdfViewerPageView(
                    sourceURL: sourceURL,
                    accentColor: tabManager.windowThemeColor
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
            } else {
                InternalPage(
                    icon: IlluminatePage.pdf.icon,
                    title: "PDF",
                    accentColor: tabManager.windowThemeColor
                ) {
                    InternalPageEmptyState(icon: "exclamationmark.triangle", message: "This PDF could not be opened.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
            }
        case nil:
            WebViewRepresentable(
                tab: tab,
                webKitManager: webKitManager,
                passwordService: passwordService,
                tabManager: tabManager,
                trackerBlockingService: trackerBlockingService,
                historyManager: historyManager,
                websitePermissionService: websitePermissionService,
                canvasFingerprintingService: canvasFingerprintingService,
                userInterfaceStyle: tabManager.userInterfaceStyle
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    @ViewBuilder
    private func contextMenuContent(for url: URL?) -> some View {
        let isWebPage = url.map { IlluminatePage(url: $0) == nil } ?? false

        Button("Refresh") {
            tab.reload()
        }
        .disabled(!isWebPage)

        if isWebPage, let url {
            Divider()
            Button("Find in Page") {
                NotificationCenter.default.post(name: .findInPage, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)

            Divider()
            Button("[Illuminate] Download") {
                let suggested = url.lastPathComponent.isEmpty ? "page.html" : url.lastPathComponent
                DownloadManager.shared.startDownload(from: url, suggestedFilename: suggested, profileID: tabManager.profileID)
            }
        }
    }
}