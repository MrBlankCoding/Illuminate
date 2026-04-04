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
    @EnvironmentObject private var redirectProtectionService: RedirectProtectionService
    
    var body: some View {
        ZStack {
            if let url = tab.url {
                if url.absoluteString == "illuminate://settings" {
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WebViewRepresentable(
                        tab: tab,
                        adBlockService: adBlockService,
                        redirectProtectionService: redirectProtectionService,
                        webKitManager: webKitManager,
                        passwordService: passwordService,
                        tabManager: tabManager,
                        userInterfaceStyle: tabManager.userInterfaceStyle
                    )
                }
            } else {
                OpeningPageView(viewModel: viewModel)
            }

            if let prompt = redirectProtectionService.activeBlockedRedirect, prompt.tabID == tab.id {
                VStack {
                    Spacer()

                    RedirectBlockedToast(
                        prompt: prompt,
                        accentColor: tabManager.windowThemeColor,
                        proceed: { redirectProtectionService.proceedWithBlockedRedirect() },
                        allow: { redirectProtectionService.allowBlockedRedirectAndProceed() },
                        dismiss: { redirectProtectionService.dismissPrompt() }
                    )
                    .padding(.bottom, 22)
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
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
                Button("[Illuminate] Download") {
                    let suggested = url.lastPathComponent.isEmpty ? "page.html" : url.lastPathComponent
                    DownloadManager.shared.startDownload(from: url, suggestedFilename: suggested)
                }
            }
        }
    }
}

private struct RedirectBlockedToast: View {
    let prompt: RedirectProtectionService.BlockedRedirectPrompt
    let accentColor: Color
    let proceed: () -> Void
    let allow: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Redirect blocked")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(prompt.sourceLabel) → \(prompt.targetLabel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button("Proceed") {
                    proceed()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accentColor)
                .clipShape(Capsule())

                Button("Allow host") {
                    allow()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accentColor)

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.2))

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 480)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 8)
    }
}
