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
    let themeColor: Color
    let onNavigate: (String) -> Void

    @Environment(ContentViewModel.self) private var viewModel: ContentViewModel
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    @State private var addressText = ""
    @State private var isHoveringSuggestions = false
    @State private var didCopyURL = false
    @State private var isCopyHovered = false
    @Namespace private var glassNamespace
    private let barGlassID = "url-bar-shell"

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme, windowThemeColor: themeColor)
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
                        .offset(y: MacDesign.Size.urlBarHeight + MacDesign.Spacing.mini)
                }
            }
        .zIndex(100)
        .onReceive(NotificationCenter.default.publisher(for: .focusURLBar)) { _ in
            focusURLBar()
        }
        .onChange(of: activeTab?.id) { oldID, newID in
            guard newID != oldID else { return }
            
            // kick out!!!!!!
            // GRAAAAH
            if isFocused {
                isFocused = false
                viewModel.setAddressBarEditing(false)
            }
            
            // update bar regardless of focus just in case
            addressText = ContentViewModel.addressBarDisplayText(for: activeTab?.url)
            
            if newID != nil && activeTab?.url == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    focusURLBar()
                }
            }
        }
        .onChange(of: activeTab?.url) { _, newURL in
            // try to keep the user out during updates
            guard !isFocused else { return }
            let display = ContentViewModel.addressBarDisplayText(for: newURL)
            if addressText != display {
                addressText = display
            }
        }
        .onChange(of: isFocused) { _, focused in
            viewModel.setAddressBarEditing(focused)
            if !focused {
                if !isHoveringSuggestions {
                    viewModel.cancelSuggestions()
                }
                // Revert in-progress edits when focus is lost without a
                // navigation (Escape, clicking away).
                let display = ContentViewModel.addressBarDisplayText(for: activeTab?.url)
                if addressText != display {
                    addressText = display
                }
            }
        }
    }

    private var barContent: some View {
        HStack(spacing: MacDesign.Spacing.control) {
            // search icon
            Image(systemName: statusIcon)
                .buttonStyle(.plain)
                .background(Color.clear)
                .allowsHitTesting(false) 

            
            TextField("Search or enter URL", text: $addressText)
                .font(.webCaption)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .focused($isFocused)
                .accessibilityIdentifier("browser.urlBar.textField")
                .accessibilityLabel("Address bar")
                .onSubmit {
                    isFocused = false
                    isHoveringSuggestions = false
                    viewModel.setAddressBarEditing(false)
                    viewModel.cancelSuggestions()
                    onNavigate(addressText)
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
                        .font(.webMicroMedium)
                        .foregroundStyle(didCopyURL ? Color.green : Color.textSecondary)
                        .frame(width: MacDesign.Size.urlBarIcon, height: MacDesign.Size.urlBarIcon)
                        .macControlBackground(isHovered: isCopyHovered, tint: didCopyURL ? .green : themeColor, radius: MacDesign.Radius.small)
                        .animation(MacDesign.fastAnimation, value: isCopyHovered)
                }
                .buttonStyle(.plain)
                .onHover { isCopyHovered = $0 }
                .hoverCursor(.pointingHand)
                .help(didCopyURL ? "Copied" : "Copy URL")
            } else {
                Color.clear.frame(width: MacDesign.Size.urlBarIcon, height: MacDesign.Size.urlBarIcon)
            }
        }
        .padding(.horizontal, MacDesign.Spacing.control + MacDesign.Spacing.hairline)
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
            radius: isFocused ? MacDesign.Radius.medium : MacDesign.Spacing.tight,
            y: isFocused ? MacDesign.Spacing.mini : MacDesign.Spacing.micro
        )
        .focusRing(isFocused)
        .font(.webCaption)
        .animation(MacDesign.springAnimation, value: isFocused)
        .hoverCursor(.iBeam)
        .onAppear {
            if addressText.isEmpty {
                addressText = ContentViewModel.addressBarDisplayText(for: activeTab?.url)
            }
            if activeTab?.url == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    focusURLBar()
                }
            }
        }
    }

    private var suggestionsDropdown: some View {
        VStack(alignment: .leading, spacing: MacDesign.Spacing.micro) {
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
        .padding(.vertical, MacDesign.Spacing.small)
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
            onNavigate(suggestion.urlString)
        }
    }

    private func selectHistorySuggestion(_ suggestion: HistorySuggestion) {
        addressText = suggestion.urlString
        isHoveringSuggestions = false
        isFocused = false
        viewModel.setAddressBarEditing(false)
        viewModel.cancelSuggestions()
        onNavigate(suggestion.urlString)
    }

    private func selectWebSuggestion(_ suggestion: String) {
        addressText = suggestion
        isHoveringSuggestions = false
        isFocused = false
        viewModel.setAddressBarEditing(false)
        viewModel.cancelSuggestions()
        onNavigate(suggestion)
    }

    private var statusIcon: String {
        if activeTab?.url?.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame {
            return "gearshape.fill"
        }
        if activeTab?.url?.scheme?.localizedCaseInsensitiveCompare("webkit-extension") == .orderedSame {
            return "puzzlepiece.fill"
        }
        if activeTab?.url?.scheme == "https" { return "lock.fill" }
        if activeTab?.url != nil { return "globe" }
        return "magnifyingglass"
    }

    private func focusURLBar() {
        isFocused = true
        viewModel.setAddressBarEditing(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
                  let fieldEditor = window.firstResponder as? NSText
            else { return }
            fieldEditor.selectAll(nil)
        }
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
            HStack(spacing: MacDesign.Spacing.control) {
                NukeFaviconView(url: suggestion.faviconURL, size: 13)
                    .frame(width: 16, height: 16)
                    .overlay {
                        // Fallback clock if favicon never loads is handled inside NukeFaviconView (globe).
                        // Keep visual size consistent with previous AsyncImage success case.
                    }

                Text(suggestion.title)
                    .font(.webMicroMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: MacDesign.Spacing.control)
            }
            .padding(.horizontal, MacDesign.Spacing.control + 2)
            .padding(.vertical, MacDesign.Spacing.mini)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.suggestionRowHover : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MacDesign.Spacing.small)
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
            HStack(spacing: MacDesign.Spacing.control) {
                ZStack {
                    RoundedRectangle(cornerRadius: MacDesign.Radius.micro, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 18, height: 18)
                    Image(systemName: suggestion.icon)
                        .font(.webSmallBold)
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: MacDesign.Spacing.hairline) {
                    HStack(spacing: MacDesign.Spacing.tight) {
                        Text(suggestion.title)
                            .font(.webMicroMedium)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        if suggestion.isCurrentlyOpenTab {
                            Text("OPEN TAB")
                                .font(.webTinyBold)
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, MacDesign.Spacing.small)
                                .padding(.vertical, MacDesign.Spacing.hairline)
                                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text(suggestion.subtitle)
                        .font(.webSmall)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: MacDesign.Spacing.control)

                if suggestion.isCurrentlyOpenTab {
                    Text("Switch to tab")
                        .font(.webMicroMedium)
                        .foregroundStyle(accentColor)
                } else {
                    Text("Illuminate Page")
                        .font(.webSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, MacDesign.Spacing.control + 2)
            .padding(.vertical, MacDesign.Spacing.mini)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.suggestionRowHover : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MacDesign.Spacing.small)
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
            HStack(spacing: MacDesign.Spacing.control) {
                Image(systemName: "magnifyingglass")
                    .font(.webSmallBold)
                    .foregroundStyle(isHovered ? accentColor : Color.textSecondary)
                    .frame(width: 16, height: 16)

                Text(text)
                    .font(.webMicro)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: MacDesign.Spacing.control)
            }
            .padding(.horizontal, MacDesign.Spacing.control + 2)
            .padding(.vertical, MacDesign.Spacing.tight)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.suggestionRowHover : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MacDesign.Spacing.small)
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
            .glassEffect(.regular, in: .rect(cornerRadius: MacDesign.Radius.urlBar))
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.urlBar, style: .continuous)
                    .fill(themeColor.opacity(isFocused ? 0.10 : 0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: MacDesign.Radius.urlBar, style: .continuous)
                    .stroke(isFocused ? themeColor.opacity(0.34) : Color.borderSubtle, lineWidth: MacDesign.Spacing.hairlineThin)
            }
    }
}
