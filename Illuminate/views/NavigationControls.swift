//
//  NavigationControls.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import WebKit

struct NavigationControls: View {
    @ObservedObject var tab: Tab
    @Environment(\.colorScheme) private var colorScheme
    let themeColor: Color

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            navButton(systemName: "chevron.left", isEnabled: tab.canGoBack, help: "Go Back") {
                tab.webView?.goBack()
            }

            navButton(systemName: "chevron.right", isEnabled: tab.canGoForward, help: "Go Forward") {
                tab.webView?.goForward()
            }

            let isActualPage = tab.url != nil
            navButton(
                systemName: tab.isLoading ? "xmark" : "arrow.clockwise",
                isEnabled: true,
                isGreyedOut: !isActualPage,
                help: tab.isLoading ? "Stop Loading" : "Reload Page"
            ) {
                if tab.isLoading {
                    tab.webView?.stopLoading()
                } else if isActualPage {
                    tab.reload()
                }
            }
        }
    }

    private func navButton(systemName: String, isEnabled: Bool, isGreyedOut: Bool = false, help: String = "", action: @escaping () -> Void) -> some View {
        NavigationControlButton(
            systemName: systemName,
            theme: theme,
            isEnabled: isEnabled,
            isGreyedOut: isGreyedOut,
            helpText: help,
            action: action
        )
    }
}

private struct NavigationControlButton: View {
    let systemName: String
    let theme: BrowserTheme
    let isEnabled: Bool
    var isGreyedOut: Bool = false
    var helpText: String = ""
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isEnabled ? (isGreyedOut ? Color.textSecondary.opacity(0.4) : Color.textPrimary) : Color.textSecondary.opacity(0.2))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isEnabled && isHovered && !isGreyedOut ? theme.buttonHoverFill : Color.clear)
                )
                .overlay(
                    Circle()
                        .strokeBorder(!isGreyedOut && isHovered ? theme.chromeStroke : Color.clear, lineWidth: 1)
                )
                .scaleEffect(!isGreyedOut && isHovered ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.14), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isGreyedOut)
        .onHover { hovering in
            isHovered = hovering
        }
        .hoverCursor(isGreyedOut ? .arrow : .pointingHand)
        .help(helpText)
    }
}
