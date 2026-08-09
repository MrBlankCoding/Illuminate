//
//  ProtectionPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 2026-08-09.
//

import SwiftUI

// illuminate://protection

struct ProtectionPageView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @Environment(\.colorScheme) private var colorScheme

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        InternalPage(
            icon: "shield.fill",
            title: "Protection",
            accentColor: tabManager.windowThemeColor
        ) {
            VStack(spacing: 16) {
                InternalPageRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ad blocker")
                                .font(.system(size: 14, weight: .medium))
                            Text("Block known advertising and tracking resources while pages load.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { environment.adBlockService.isEnabled },
                            set: { environment.adBlockService.isEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }

            }
        }
    }
}
