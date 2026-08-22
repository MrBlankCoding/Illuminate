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
        HStack(spacing: 1) {
            navButton(systemName: "chevron.left", identifier: "browser.navigation.backButton", isEnabled: tab.canGoBack, help: "Go Back") {
                tab.webView?.goBack()
            }

            navButton(systemName: "chevron.right", identifier: "browser.navigation.forwardButton", isEnabled: tab.canGoForward, help: "Go Forward") {
                tab.webView?.goForward()
            }

            let isActualPage = tab.url != nil
            navButton(
                systemName: tab.isLoading ? "xmark" : "arrow.clockwise",
                identifier: "browser.navigation.reloadButton",
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
        .navClusterBackground()
    }

    private func navButton(systemName: String, identifier: String, isEnabled: Bool, isGreyedOut: Bool = false, help: String = "", action: @escaping () -> Void) -> some View {
        NavigationControlButton(
            systemName: systemName,
            identifier: identifier,
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
    let identifier: String
    let theme: BrowserTheme
    let isEnabled: Bool
    var isGreyedOut: Bool = false
    var helpText: String = ""
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(symbolColor)
                .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
                .macControlBackground(isHovered: isEnabled && isHovered && !isGreyedOut, tint: theme.accent, radius: 999)
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
    }

    private var symbolColor: Color {
        guard isEnabled else {
            return Color.textSecondary.opacity(0.28)
        }
        if isGreyedOut {
            return Color.textSecondary.opacity(0.42)
        }
        return isHovered ? Color.textPrimary : Color.textSecondary
    }
}

struct NavClusterBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(3)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(0.035))
            }
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            }
    }
}

extension View {
    func navClusterBackground() -> some View {
        modifier(NavClusterBackgroundModifier())
    }
}
