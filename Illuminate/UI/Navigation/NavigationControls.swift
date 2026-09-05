//
//  NavigationControls.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import WebKit
import Observation

struct NavigationControls: View {
    var tab: Tab
    @Environment(\.colorScheme) private var colorScheme
    let themeColor: Color
    let windowThemeColor: Color

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme, windowThemeColor: windowThemeColor)
    }

    var body: some View {
        HStack(spacing: MacDesign.Spacing.hairline) {
            navButton(systemName: "chevron.left", identifier: "browser.navigation.backButton", isEnabled: tab.canGoBack, help: "Go Back", accessibilityLabel: "Back") {
                tab.webView?.goBack()
            }

            navButton(systemName: "chevron.right", identifier: "browser.navigation.forwardButton", isEnabled: tab.canGoForward, help: "Go Forward", accessibilityLabel: "Forward") {
                tab.webView?.goForward()
            }

            let isActualPage = tab.url != nil
            navButton(
                systemName: tab.isLoading ? "xmark" : "arrow.clockwise",
                identifier: "browser.navigation.reloadButton",
                isEnabled: true,
                isGreyedOut: !isActualPage,
                help: tab.isLoading ? "Stop Loading" : "Reload Page",
                accessibilityLabel: tab.isLoading ? "Stop" : "Reload"
            ) {
                if tab.isLoading {
                    tab.webView?.stopLoading()
                } else if isActualPage {
                    tab.reload()
                }
            }
        }
        .navClusterBackground()
    }

    private func navButton(systemName: String, identifier: String, isEnabled: Bool, isGreyedOut: Bool = false, help: String = "", accessibilityLabel: String = "", action: @escaping () -> Void) -> some View {
        NavigationControlButton(
            systemName: systemName,
            identifier: identifier,
            theme: theme,
            isEnabled: isEnabled,
            isGreyedOut: isGreyedOut,
            helpText: help,
            accessibilityLabel: accessibilityLabel.isEmpty ? help : accessibilityLabel,
            action: action
        )
    }
}

private struct NavigationControlButton: View {
    let systemName: String
    let identifier: String
    let theme: BrowserTheme
    let isEnabled: Bool
    var isGreyedOut: Bool = false
    var helpText: String = ""
    var accessibilityLabel: String = ""
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.webMicroMedium)
                .foregroundStyle(symbolColor)
                .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
                .macControlBackground(isHovered: isEnabled && isHovered && !isGreyedOut, tint: theme.accent, radius: MacDesign.Radius.full)
                .contentShape(Circle())
                .animation(MacDesign.fastAnimation, value: isHovered)
        }
        .buttonStyle(ToolbarIconPressStyle())
        .disabled(!isEnabled || isGreyedOut)
        .onHover { hovering in
            isHovered = hovering
        }
        .hoverCursor(isGreyedOut ? .arrow : .pointingHand)
        .help(helpText)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel.isEmpty ? helpText : accessibilityLabel)
    }

    private var symbolColor: Color {
        guard isEnabled else {
            return Color.textTertiary
        }
        if isGreyedOut {
            return Color.textTertiary.opacity(0.42)
        }
        return isHovered ? Color.textPrimary : Color.textSecondary
    }
}
