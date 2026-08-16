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
    @Namespace private var glassNamespace
    private let barGlassID = "url-bar-shell"

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme)
    }

    private var showSuggestions: Bool {
        isFocused && !viewModel.historySuggestions.isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            barContent
                .zIndex(1)

            if showSuggestions {
                suggestionsDropdown
                    .offset(y: MacDesign.Size.urlBarHeight + 6)
                    .zIndex(2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(MacDesign.springAnimation, value: showSuggestions)
        .onReceive(NotificationCenter.default.publisher(for: .focusURLBar)) { _ in
            isFocused = true
        }
        .onChange(of: isFocused) { _, focused in
            viewModel.setAddressBarEditing(focused)
            if !focused { viewModel.cancelSuggestions() }
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
                    onNavigate()
                    viewModel.setAddressBarEditing(false)
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
        VStack(alignment: .leading, spacing: 1) {
            Text("SUGGESTIONS")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.textSecondary.opacity(0.65))
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 4)

            ForEach(viewModel.historySuggestions) { suggestion in
                SuggestionRowView(suggestion: suggestion) {
                    addressText = suggestion.urlString
                    viewModel.cancelSuggestions()
                    isFocused = false
                    onNavigate()
                }
            }
        }
        .padding(.vertical, 6)
        .floatingGlassPanel(cornerRadius: MacDesign.Radius.medium)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("History suggestions")
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
            HStack(spacing: 10) {
                AsyncImage(url: suggestion.faviconURL) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit().frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(suggestion.urlString)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(suggestion.recencyLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .hoverCursor(.pointingHand)
        .onHover { hovering in
            withAnimation(MacDesign.fastAnimation) { isHovered = hovering }
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
