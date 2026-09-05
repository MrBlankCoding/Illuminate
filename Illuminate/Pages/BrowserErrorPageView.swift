//
//  BrowserErrorPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/10/26.
//

import SwiftUI
import WebKit

struct BrowserErrorPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme

    let error: NetworkErrorKind

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    private var accentColor: Color {
        switch error {
        case .tls:     return .red
        case .blocked: return .orange
        default:       return tabManager.windowThemeColor
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous)
                            .fill(accentColor.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Image(systemName: error.icon)
                            .font(.webInternalPageIcon)
                            .foregroundStyle(accentColor)
                    }

                    Text(error.title)
                        .font(.webInternalPageTitle)
                        .foregroundStyle(Color.textPrimary)
                }

                InternalPageRow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What happened")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.4)

                        Text(error.detail)
                            .font(.webCaption)
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let guidance = guidanceText {
                    InternalPageRow {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What you can do")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.4)

                            Text(guidance)
                                .font(.webCaption)
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: MacDesign.Spacing.medium) {
                    Button("Try Again") {
                        tabManager.activeTab?.reload()
                    }
                    .buttonStyle(InternalPageChipButtonStyle(color: accentColor))

                    if tabManager.activeTab?.canGoBack == true {
                        Button("Go Back") {
                            tabManager.activeTab?.webView?.goBack()
                        }
                        .buttonStyle(InternalPageChipButtonStyle(color: .secondary))
                    }
                }
                .padding(.top, 4)
            }
            .padding(MacDesign.Spacing.pageHeaderPadding)
            .frame(maxWidth: MacDesign.Size.internalPageMax, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.windowBase)
    }


    private var guidanceText: String? {
        switch error {
        case .dns:
            return "Check that you typed the address correctly. If the address is correct, the site may be temporarily unavailable or there may be a problem with your DNS settings."
        case .tls:
            return "This may mean the site's security certificate is expired, misconfigured, or that someone is intercepting the connection. Do not enter sensitive information on this site."
        case .noConnection:
            return "Check your Wi-Fi or Ethernet connection. If you're on Wi-Fi, try moving closer to your router. You can also try opening another site to confirm your connection is working."
        case .blocked:
            return "HTTPS-only mode is enabled in Protection settings. You can disable it there if you need to access HTTP sites."
        case .generic:
            return nil
        }
    }
}
