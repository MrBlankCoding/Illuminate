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
        LiquidGlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    showingPageInfo = true
                } label: {
                    Image(systemName: statusIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isFocused ? themeColor : Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(showingPageInfo ? theme.itemActive : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .hoverCursor(.pointingHand)
                .modifier(
                    URLBarAccessoryGlassModifier(
                        namespace: glassNamespace,
                        id: "url-bar-status",
                        tint: isFocused ? themeColor : nil
                    )
                )
                .popover(isPresented: $showingPageInfo, arrowEdge: .bottom) {
                    PageInfoPopoverView(tab: activeTab)
                        .glassBackground()
                }

                TextField("Search or enter URL", text: $addressText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .focused($isFocused)
                    .accessibilityIdentifier("browser.urlBar.textField")
                    .onSubmit {
                        isFocused = false
                        viewModel.setAddressBarEditing(false)
                        onNavigate()
                    }

                HStack(spacing: 6) {
                    if !addressText.isEmpty {
                        Button {
                            copyAddressToPasteboard()
                        } label: {
                            Image(systemName: didCopyURL ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(didCopyURL ? Color.green : Color.textSecondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(isCopyHovered ? theme.itemHover : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(isCopyHovered ? Color.borderSubtle : Color.clear, lineWidth: 1)
                                )
                                .scaleEffect(isCopyHovered ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.14), value: isCopyHovered)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isCopyHovered = hovering
                        }
                        .hoverCursor(.pointingHand)
                        .help(didCopyURL ? "Copied" : "Copy URL")
                        .modifier(
                            URLBarAccessoryGlassModifier(
                                namespace: glassNamespace,
                                id: "url-bar-copy",
                                tint: didCopyURL ? .green : (isFocused ? themeColor : nil)
                            )
                        )
                    } else {
                        Color.clear
                            .frame(width: 32, height: 28)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(
                URLBarShellGlassModifier(
                    namespace: glassNamespace,
                    id: barGlassID,
                    isFocused: isFocused,
                    themeColor: themeColor
                )
            )
            .modifier(URLBarStrokeModifier(isFocused: isFocused, themeColor: themeColor))
            .shadow(
                color: themeColor.opacity(isFocused ? 0.18 : 0.08),
                radius: isFocused ? 16 : 10,
                y: isFocused ? 7 : 4
            )
        }
        .focusRing(isFocused)
        .font(.system(size: 14, weight: .medium, design: .rounded))
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
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(themeColor.opacity(isFocused ? 0.14 : 0.06))
                        .interactive(),
                    in: Capsule()
                )
                .glassEffectID(id, in: namespace)
        } else {
            content
                .background(Capsule().fill(.regularMaterial))
        }
    }
}

private struct URLBarAccessoryGlassModifier: ViewModifier {
    let namespace: Namespace.ID
    let id: String
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let effect: Glass = tint.map {
                .regular.tint($0.opacity(0.12)).interactive()
            } ?? .regular.interactive()

            content
                .glassEffect(effect, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

private struct URLBarStrokeModifier: ViewModifier {
    let isFocused: Bool
    let themeColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
        } else {
            content.overlay(
                Capsule()
                    .strokeBorder(isFocused ? themeColor.opacity(0.35) : Color.borderSubtle, lineWidth: 1)
            )
        }
    }
}
