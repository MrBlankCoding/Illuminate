//
//  StatusBar.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct StatusBar: View {
    let tab: Tab?
    @EnvironmentObject private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        Group {
            if let label = statusLabel {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(theme.statusFill)
                            .overlay(
                                Capsule()
                                    .strokeBorder(theme.chromeStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
            }
        }
        .animation(.easeOut(duration: 0.16), value: statusLabel)
    }

    private var statusLabel: String? {
        if let hoveredLink = tab?.hoveredLinkURLString, !hoveredLink.isEmpty {
            return hoveredLink
        }

        return nil
    }
}
