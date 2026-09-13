//
//  ProtectionPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

// illuminate://protection

struct ProtectionPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(WebKitManager.self) private var webKitManager: WebKitManager

    var body: some View {
        InternalPage(
            icon: "shield.fill",
            title: "Privacy & Protection",
            accentColor: tabManager.windowThemeColor
        ) {
            VStack(alignment: .leading, spacing: 24) {
                httpsSection
                PrivacySettingsView(isEmbedded: true)
            }
        }
    }

    private var httpsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "Security")

            InternalPageRow {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HTTPS-only mode")
                            .font(.system(size: 14, weight: .medium))

                        Text("Block requests to sites that don't support HTTPS.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { webKitManager.httpsOnlyEnabled },
                            set: { webKitManager.httpsOnlyEnabled = $0 }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("HTTPS-only mode")
                    .accessibilityIdentifier(
                        "browser.protection.httpsOnlyToggle"
                    )
                }
            }
        }
    }
}
