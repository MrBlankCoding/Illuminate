//
//  URLBar.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Combine
import SwiftUI
import AppKit

struct URLBar: View {
    let activeTab: Tab?
    @Binding var addressText: String
    let themeColor: Color
    let onNavigate: () -> Void

    @EnvironmentObject private var viewModel: ContentViewModel
    @EnvironmentObject private var urlSynchronizer: URLSynchronizer
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    @State private var didCopyURL = false
    @State private var isCopyHovered = false
    @State private var showingPageInfo = false
    @Namespace private var glassNamespace
    private let barGlassID = "url-bar-shell"

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 8) {
                Button {
                    showingPageInfo = true
                } label: {
                    Image(systemName: statusIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isFocused ? themeColor : Color.textSecondary)
                        .frame(width: 22, height: 22)
                        .macControlBackground(isActive: showingPageInfo, isHovered: false, tint: themeColor, radius: 7)
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .popover(isPresented: $showingPageInfo, arrowEdge: .bottom) {
                    PageInfoPopoverView(tab: activeTab)
                        .macPopover()
                }

                TextField("Search or enter URL", text: $addressText)
                    .font(.system(size: 13, weight: .regular))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .focused($isFocused)
                    .accessibilityIdentifier("browser.urlBar.textField")
                    .onSubmit {
                        isFocused = false
                        onNavigate()
                        viewModel.setAddressBarEditing(false)
                    }

                    if !addressText.isEmpty {
                        Button {
                            copyAddressToPasteboard()
                        } label: {
                            Image(systemName: didCopyURL ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(didCopyURL ? Color.green : Color.textSecondary)
                                .frame(width: 22, height: 22)
                                .macControlBackground(isHovered: isCopyHovered, tint: didCopyURL ? .green : themeColor, radius: 7)
                                .animation(MacDesign.fastAnimation, value: isCopyHovered)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isCopyHovered = hovering
                        }
                        .hoverCursor(.pointingHand)
                        .help(didCopyURL ? "Copied" : "Copy URL")
                    } else {
                        Color.clear
                            .frame(width: 22, height: 22)
                    }
            }
            .padding(.horizontal, 9)
            .frame(height: MacDesign.Size.urlBarHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(
                URLBarShellGlassModifier(
                    namespace: glassNamespace,
                    id: barGlassID,
                    isFocused: isFocused,
                    themeColor: themeColor
                )
            )
            .shadow(
                color: Color.black.opacity(isFocused ? 0.10 : 0.04),
                radius: isFocused ? 12 : 6,
                y: isFocused ? 5 : 2
            )
        .focusRing(isFocused)
        .font(.system(size: 13, weight: .regular))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
        .hoverCursor(.iBeam)
        .onAppear {
            if addressText.isEmpty {
                addressText = activeTab?.url?.absoluteString ?? urlSynchronizer.currentURL?.absoluteString ?? ""
            }
        }
        .onReceive(urlSynchronizer.$currentURL) { newURL in
            guard !isFocused else { return }
            addressText = newURL?.absoluteString ?? ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusURLBar)) { _ in
            isFocused = true
        }
        .onChange(of: isFocused) { _, focused in
            viewModel.setAddressBarEditing(focused)
        }
    }

    private var statusIcon: String {
        if activeTab?.url?.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame {
            return "gearshape.fill"
        }
        if activeTab?.url?.scheme == "https" {
            return "lock.fill"
        }
        if activeTab?.url != nil {
            return "globe"
        }
        return "magnifyingglass"
    }

    private func copyAddressToPasteboard() {
        let value = activeTab?.url?.absoluteString ?? addressText
        guard !value.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        didCopyURL = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            didCopyURL = false
        }
    }
}

private struct URLBarShellGlassModifier: ViewModifier {
    let namespace: Namespace.ID
    let id: String
    let isFocused: Bool
    let themeColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(themeColor.opacity(isFocused ? 0.10 : 0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isFocused ? themeColor.opacity(0.34) : Color.primary.opacity(0.10), lineWidth: 0.5)
            }
    }
}

private struct URLBarAccessoryGlassModifier: ViewModifier {
    let namespace: Namespace.ID
    let id: String
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background {
                if let tint {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.14))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
            }
    }
}

private struct URLBarStrokeModifier: ViewModifier {
    let isFocused: Bool
    let themeColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        content
    }
}
