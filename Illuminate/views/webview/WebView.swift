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
    
    var body: some View {
        ZStack {
            if let url = tab.url {
                if url.absoluteString == "illuminate://settings" {
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WebViewRepresentable(tab: tab, tabManager: tabManager, userInterfaceStyle: tabManager.userInterfaceStyle)
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
            if let url = tab.url, url.scheme != "illuminate" {
                Divider()
                Button("Find in Page") {
                    NotificationCenter.default.post(name: .findInPage, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Divider()
                Button("Download Page") {
                    if #available(macOS 12.0, *), let webView = tab.webView {
                        Task {
                            await webView.startDownload(using: URLRequest(url: url))
                        }
                    } else {
                        let suggested = url.lastPathComponent.isEmpty ? "page.html" : url.lastPathComponent
                        DownloadManager.shared.startDownload(from: url, suggestedFilename: suggested)
                    }
                }
            }
        }
    }
}
