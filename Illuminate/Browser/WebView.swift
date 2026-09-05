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
    var tab: Tab

    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var profileEnvironment: ProfileEnvironment
    @Environment(WebKitManager.self) private var webKitManager: WebKitManager
    @Environment(PasswordService.self) private var passwordService: PasswordService
    @Environment(TrackerBlockingService.self) private var trackerBlockingService: TrackerBlockingService
    @Environment(HistoryManager.self) private var historyManager: HistoryManager
    @Environment(WebsitePermissionService.self) private var websitePermissionService: WebsitePermissionService
    @Environment(CanvasFingerprintingService.self) private var canvasFingerprintingService: CanvasFingerprintingService

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
        case .easel:
            if let easelID = Easel.id(from: url),
               profileEnvironment.easelManager.easel(for: easelID) != nil {
                EaselView(easelID: easelID, easelManager: profileEnvironment.easelManager, tab: tab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.container, edges: .bottom)
            } else {
                EaselListView()
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