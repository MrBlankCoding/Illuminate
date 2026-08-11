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
    @EnvironmentObject private var viewModel: ContentViewModel
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var adBlockService: AdBlockService
    @EnvironmentObject private var webKitManager: WebKitManager
    @EnvironmentObject private var passwordService: PasswordService
    @EnvironmentObject private var trackerBlockingService: TrackerBlockingService
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var websitePermissionService: WebsitePermissionService

    var body: some View {
        ZStack {
            if let url = tab.url {
                switch illuminatePage(for: url) {
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
                case .none:
                    WebViewRepresentable(
                        tab: tab,
                        adBlockService: adBlockService,
                        webKitManager: webKitManager,
                        passwordService: passwordService,
                        tabManager: tabManager,
                        trackerBlockingService: trackerBlockingService,
                        historyManager: historyManager,
                        websitePermissionService: websitePermissionService,
                        userInterfaceStyle: tabManager.userInterfaceStyle
                    )
                }
            } else {
                NewTabView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .bottom)
        .contextMenu {
            Button("Refresh") {
                tab.reload()
            }
            if let url = tab.url, illuminatePage(for: url) == nil {
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

    private enum IlluminatePage: Equatable {
        case passwords, cookies, protection, downloads, history, permissions
    }

    private func illuminatePage(for url: URL) -> IlluminatePage? {
        guard url.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame else {
            return nil
        }
        switch url.host?.lowercased() {
        case "passwords":  return .passwords
        case "cookies":    return .cookies
        case "protection": return .protection
        case "downloads":  return .downloads
        case "history":    return .history
        case "permissions": return .permissions
        default:           return nil
        }
    }
}
