//
//  OpeningPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI


struct OpeningPageView: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var googleSuggestions: [String] = []
    @State private var suggestionTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @Namespace private var searchGlassNamespace
    @State private var isCustomizePanelShown = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 48) {
                    Spacer()

                    VStack(spacing: 6) {
                        Text("Illuminate")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(Color.textPrimary)
                    }

                    searchBar

                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Button {
                    withAnimation(MacDesign.springAnimation) {
                        isCustomizePanelShown.toggle()
                    }
                } label: {
                    Image(systemName: isCustomizePanelShown ? "xmark" : "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(
                            isCustomizePanelShown
                                ? tabManager.windowThemeColor.opacity(0.85)
                                : Color.primary.opacity(0.08),
                            in: Circle()
                        )
                        .foregroundStyle(isCustomizePanelShown ? .white : Color.primary.opacity(0.7))
                        .overlay {
                            Circle()
                                .stroke(
                                    isCustomizePanelShown
                                        ? tabManager.windowThemeColor
                                        : Color.primary.opacity(0.12),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(
                            color: isCustomizePanelShown
                                ? tabManager.windowThemeColor.opacity(0.35)
                                : .black.opacity(0.10),
                            radius: isCustomizePanelShown ? 8 : 4
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(isCustomizePanelShown ? 1.05 : 1)
                .animation(MacDesign.springAnimation, value: isCustomizePanelShown)
                .accessibilityLabel(isCustomizePanelShown ? "Close customize panel" : "Customize new tab page")
                .help(isCustomizePanelShown ? "Close" : "Customize")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isCustomizePanelShown {
                NewTabCustomizePanel()
                    .environmentObject(tabManager)
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
        .ignoresSafeArea()
        .preferredColorScheme(tabManager.userInterfaceStyle.colorScheme)
        .onChange(of: searchText) { _, newQuery in
            scheduleSuggestions(for: newQuery)
        }
        .onDisappear {
            suggestionTask?.cancel()
            isCustomizePanelShown = false
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFieldFocused = true
            }
        }
    }

    private var searchBar: some View {
        LiquidGlassGroup(spacing: 8) {
        HStack(spacing: 10) {

            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search the web or enter URL", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    googleSuggestions = []
                    navigate(with: searchText)
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 560)
        .liquidGlassCapsule(tint: isSearchFieldFocused ? tabManager.windowThemeColor : nil)
        .modifier(GlassEffectIDModifier(id: "opening-search", namespace: searchGlassNamespace))
        .hoverCursor(.iBeam)
        .overlay(alignment: .top) {

            if isSearchFieldFocused && !googleSuggestions.isEmpty {

                VStack(alignment: .leading, spacing: 0) {

                    ForEach(googleSuggestions, id: \.self) { suggestion in

                        Button {

                            searchText = suggestion
                            googleSuggestions = []
                            navigate(with: suggestion)

                        } label: {

                            HStack(spacing: 10) {

                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)

                                Text(suggestion)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if suggestion != googleSuggestions.last {
                            Divider().padding(.horizontal, 8)
                        }
                    }
                }
                .frame(maxWidth: 560)
                .glassBackground(cornerRadius: 14)
                .modifier(GlassEffectIDModifier(id: "opening-suggestions", namespace: searchGlassNamespace))
                .offset(y: 58)
                .shadow(radius: 20)
                .zIndex(1000)
            }
        }
        }
    }

    private var backgroundView: some View {
        ZStack {
            fallbackBackground

            if let backgroundImageURL {
                CachedBackgroundImageView(url: backgroundImageURL)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(theme.isDark ? 0.18 : 0.08),
                                Color.clear,
                                Color.black.opacity(theme.isDark ? 0.28 : 0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
    }

    private var fallbackBackground: Color {
        theme.isDark ? .black : .white
    }

    private var backgroundImageURL: URL? {
        guard !tabManager.backgroundImageURL.isEmpty else { return nil }
        return URL(string: tabManager.backgroundImageURL)
    }

    private func navigate(with query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.addressBarText = trimmed
        viewModel.navigateToAddressBarURL()

        searchText = ""
    }

    private func scheduleSuggestions(for query: String) {

        suggestionTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, !isLikelyURL(trimmed) else {
            googleSuggestions = []
            return
        }

        suggestionTask = Task {

            try? await Task.sleep(nanoseconds: 110_000_000)

            guard !Task.isCancelled else { return }

            let suggestions = await fetchGoogleSuggestions(query: trimmed)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.googleSuggestions = suggestions
            }
        }
    }

    private func fetchGoogleSuggestions(query: String) async -> [String] {

        guard
            let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://suggestqueries.google.com/complete/search?client=chrome&q=\(escaped)")
        else {
            return []
        }

        do {

            let (data, _) = try await URLSession.shared.data(from: url)

            guard
                let payload = try JSONSerialization.jsonObject(with: data) as? [Any],
                payload.count > 1,
                let suggestions = payload[1] as? [String]
            else {
                return []
            }

            return Array(suggestions.prefix(6))

        } catch {
            return []
        }
    }

    private func isLikelyURL(_ input: String) -> Bool {

        if let url = URL(string: input), url.scheme != nil {
            return true
        }

        return input.contains(".") && !input.contains(" ")
    }
}
