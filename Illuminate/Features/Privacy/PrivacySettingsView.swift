//
//  PrivacySettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/10/26.
//

import SwiftUI

struct PrivacySettingsView: View {
    let isEmbedded: Bool
    @Environment(HistoryManager.self) private var historyManager: HistoryManager
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(CanvasFingerprintingService.self) private var canvasFingerprintingService: CanvasFingerprintingService
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @Environment(WebKitManager.self) private var webKitManager: WebKitManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showClearCookiesConfirmation = false

    init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    var body: some View {
        Group {
            if isEmbedded {
                settingsContent
            } else {
                ScrollView { settingsContent.padding(24) }
            }
        }
        .confirmationDialog(
            "Clear all cookies and website data?",
            isPresented: $showClearCookiesConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                CookieViewModel().clearAllCookies(with: environment.webKitManager)
                HapticFeedback.destructiveAction()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will sign you out of all websites.")
        }
    }

    private var settingsContent: some View {
        @Bindable var historyManager = historyManager
        @Bindable var webKitManager = webKitManager
        @Bindable var canvasFingerprintingService = canvasFingerprintingService
        return VStack(alignment: .leading, spacing: 24) {
                settingsSection(title: "Browsing History") {
                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "clock",
                            title: "Save browsing history",
                            subtitle: "Pages you visit are saved to your history.",
                            isOn: $historyManager.isSavingEnabled
                        )
                        Divider().padding(.leading, 48)
                        toggleRow(
                            icon: "star.square.on.square",
                            title: "Show frequently visited sites",
                            subtitle: "Top sites appear on the new tab page.",
                            isOn: $historyManager.showTopSites
                        )
                        Divider().padding(.leading, 48)
                        toggleRow(
                            icon: "text.magnifyingglass",
                            title: "Show history suggestions",
                            subtitle: "Previously visited pages appear in the address bar.",
                            isOn: $historyManager.showHistorySuggestions
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                }

                settingsSection(title: "Cookies") {
                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "circle.hexagongrid.fill",
                            title: "Enable cookies",
                            subtitle: "Allow websites to store sign-in, preference, and session data.",
                            isOn: $webKitManager.cookiesEnabled,
                            accessibilityID: "browser.cookies.enabledToggle"
                        )
                        Divider().padding(.leading, 48)
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(tabManager.windowThemeColor)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear all cookies and website data")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Removes stored data for all sites. You'll be signed out everywhere.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Clear") {
                                showClearCookiesConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                            .accessibilityIdentifier("browser.cookies.clearButton")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                }

                settingsSection(title: "Fingerprinting") {
                    toggleRow(
                        icon: "hand.raised.shield.fill",
                        title: "Block canvas fingerprinting",
                        subtitle: "Limits websites from identifying this browser through canvas rendering.",
                        isOn: $canvasFingerprintingService.isEnabled
                    )
                }

            Spacer()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            content()
        }
    }

    @ViewBuilder
    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        accessibilityID: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tabManager.windowThemeColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tabManager.windowThemeColor)
                .accessibilityLabel(Text(title))
                .accessibilityIdentifier(accessibilityID ?? "")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

}
