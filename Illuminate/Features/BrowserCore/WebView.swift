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
        case .cookies:
            CookiesPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .protection:
            ProtectionPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .downloads:
            DownloadsPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .history:
            HistoryPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .permissions:
            PermissionsPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .info:
            InfoPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .extensions:
            ExtensionSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                DownloadManager.shared.startDownload(from: url, suggestedFilename: suggested)
            }
        }
    }
}