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
                case .none:
                    WebViewRepresentable(
                        tab: tab,
                        adBlockService: adBlockService,
                        webKitManager: webKitManager,
                        passwordService: passwordService,
                        tabManager: tabManager,
                        userInterfaceStyle: tabManager.userInterfaceStyle
                    )
                }
            } else {
                OpeningPageView(viewModel: viewModel)
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

    // MARK: - Illuminate internal page routing

    private enum IlluminatePage: Equatable {
        case passwords, cookies, protection
    }

    private func illuminatePage(for url: URL) -> IlluminatePage? {
        guard url.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame else {
            return nil
        }
        switch url.host?.lowercased() {
        case "passwords":  return .passwords
        case "cookies":    return .cookies
        case "protection": return .protection
        default:           return nil
        }
    }
}
