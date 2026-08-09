//
//  CookiesPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

struct CookiesPageView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @Environment(\.colorScheme) private var colorScheme

    @State private var showClearConfirmation = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        InternalPage(
            icon: "circle.hexagongrid.fill",
            title: "Cookies & Website Data",
            accentColor: tabManager.windowThemeColor
        ) {
            VStack(spacing: 16) {
                InternalPageRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Enable cookies")
                                .font(.system(size: 14, weight: .medium))
                            Text("Allow websites to store sign-in, preference, and session data.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { environment.webKitManager.cookiesEnabled },
                            set: { environment.webKitManager.cookiesEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }

                InternalPageRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Clear all cookies and website data")
                                .font(.system(size: 14, weight: .medium))
                            Text("Removes stored data for all sites. You'll be signed out everywhere.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Clear") {
                            showClearConfirmation = true
                        }
                        .buttonStyle(InternalPageChipButtonStyle(color: .red))
                    }
                }
                .confirmationDialog(
                    "Clear all cookies and website data?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear All", role: .destructive) {
                        CookieViewModel().clearAllCookies(with: environment.webKitManager)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will sign you out of all websites.")
                }
            }
        }
    }
}
