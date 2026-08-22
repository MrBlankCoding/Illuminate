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
    @EnvironmentObject private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    @State private var isHoveringSuggestions = false
    @State private var didCopyURL = false
    @State private var isCopyHovered = false
    @Namespace private var glassNamespace
    private let barGlassID = "url-bar-shell"

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme)
    }

    private var showSuggestions: Bool {
        (isFocused || isHoveringSuggestions) && (
            !viewModel.illuminatePageSuggestions.isEmpty ||
            !viewModel.historySuggestions.isEmpty ||
            !viewModel.webSuggestions.isEmpty
        )
    }

    var body: some View {
        barContent
            .overlay(alignment: .top) {
                if showSuggestions {
                    suggestionsDropdown
                        .offset(y: MacDesign.Size.urlBarHeight + 5)
                }
            }
        .zIndex(100)
        .onReceive(NotificationCenter.default.publisher(for: .focusURLBar)) { _ in
            isFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder as? NSText {
                    firstResponder.selectAll(nil)
                }
            }
        }
        .onChange(of: activeTab?.id) { oldID, newID in
            if newID != nil && activeTab?.url == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .onChange(of: isFocused) { _, focused in
            viewModel.setAddressBarEditing(focused)
            if !focused && !isHoveringSuggestions {
                viewModel.cancelSuggestions()
            }
        }
    }

    private var barContent: some View {
        HStack(spacing: 8) {
            // search icon
            Image(systemName: statusIcon)
                .buttonStyle(.plain)
                .background(Color.clear)
                .allowsHitTesting(false) 

            
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
                    isHoveringSuggestions = false
                    viewModel.setAddressBarEditing(false)
                    viewModel.cancelSuggestions()
                    onNavigate()
                }
                .onChange(of: addressText) { _, newValue in
                    if isFocused {
                        viewModel.updateSuggestions(for: newValue)
                    }
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
                .onHover { isCopyHovered = $0 }
                .hoverCursor(.pointingHand)
                .help(didCopyURL ? "Copied" : "Copy URL")
            } else {
                Color.clear.frame(width: 22, height: 22)
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
    }

    private var suggestionsDropdown: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(viewModel.illuminatePageSuggestions) { suggestion in
                IlluminatePageSuggestionRowView(suggestion: suggestion, accentColor: themeColor) {
                    selectIlluminatePageSuggestion(suggestion)
                }
            }

            ForEach(viewModel.historySuggestions) { suggestion in
                SuggestionRowView(suggestion: suggestion) {
                    selectHistorySuggestion(suggestion)
                }
            }

            ForEach(viewModel.webSuggestions, id: \.self) { suggestion in
                WebSuggestionRowView(text: suggestion, accentColor: themeColor) {
                    selectWebSuggestion(suggestion)
                }
            }
        }
        .padding(.vertical, 4)
        .background(theme.windowBase.opacity(0.72), in: RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
        .floatingGlassPanel(cornerRadius: MacDesign.Radius.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Search suggestions")
        .onHover { hovering in
            isHoveringSuggestions = hovering
        }
    }

    private func selectIlluminatePageSuggestion(_ suggestion: IlluminatePageSuggestion) {
        isHoveringSuggestions = false
        isFocused = false
        viewModel.setAddressBarEditing(false)
        viewModel.cancelSuggestions()

        if suggestion.isCurrentlyOpenTab, let tabID = suggestion.openTabID {
            tabManager.switchTo(tabID)
        } else {
            addressText = suggestion.urlString
            onNavigate()
        }
    }

    private func selectHistorySuggestion(_ suggestion: HistorySuggestion) {
        addressText = suggestion.urlString
        isHoveringSuggestions = false
        isFocused = false
        viewModel.setAddressBarEditing(false)
        viewModel.cancelSuggestions()
        onNavigate()
    }

    private func selectWebSuggestion(_ suggestion: String) {
        addressText = suggestion
        isHoveringSuggestions = false
        isFocused = false
        viewModel.setAddressBarEditing(false)
        viewModel.cancelSuggestions()
        onNavigate()
    }

    private var statusIcon: String {
        if activeTab?.url?.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame {
            return "gearshape.fill"
        }
        if activeTab?.url?.scheme == "https" { return "lock.fill" }
        if activeTab?.url != nil { return "globe" }
        return "magnifyingglass"
    }

    private func copyAddressToPasteboard() {
        let value = activeTab?.url?.absoluteString ?? addressText
        guard !value.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        didCopyURL = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { didCopyURL = false }
    }
}

private struct SuggestionRowView: View {
    let suggestion: HistorySuggestion
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                AsyncImage(url: suggestion.faviconURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit().frame(width: 13, height: 13)
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 16, height: 16)

                Text(suggestion.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .hoverCursor(.pointingHand)
        .onHover { hovering in
            withAnimation(MacDesign.fastAnimation) { isHovered = hovering }
        }
    }
}

private struct IlluminatePageSuggestionRowView: View {
    let suggestion: IlluminatePageSuggestion
    let accentColor: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 18, height: 18)
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(suggestion.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        if suggestion.isCurrentlyOpenTab {
                            Text("OPEN TAB")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text(suggestion.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if suggestion.isCurrentlyOpenTab {
                    Text("Switch to tab")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accentColor)
                } else {
                    Text("Illuminate Page")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .hoverCursor(.pointingHand)
        .onHover { isHovered = $0 }
    }
}

private struct WebSuggestionRowView: View {
    let text: String
    let accentColor: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isHovered ? accentColor : Color.textSecondary)
                    .frame(width: 16, height: 16)

                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .hoverCursor(.pointingHand)
        .onHover { isHovered = $0 }
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
            .glassEffect(.regular, in: .rect(cornerRadius: 11))
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
