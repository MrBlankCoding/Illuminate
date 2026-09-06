//
//  BrowserToolbarView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//


import SwiftUI
import AppKit

final class WindowDragNSView: NSView {
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let wasMovable = window.isMovable
        window.isMovable = true
        window.performDrag(with: event)
        window.isMovable = wasMovable
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        WindowDragNSView()
    }

    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

final class TabStripContainerNSView: NSView {
    private var hostingView: NSHostingView<AnyView>?

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func configure(with rootView: AnyView) {
        if hostingView == nil {
            let hosting = NSHostingView(rootView: rootView)
            hosting.translatesAutoresizingMaskIntoConstraints = true
            hosting.autoresizingMask = [.width, .height]
            hosting.frame = bounds
            hosting.safeAreaRegions = []
            addSubview(hosting)
            hostingView = hosting
        } else {
            hostingView?.rootView = rootView
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        window?.isMovable = false
    }

    override func mouseExited(with event: NSEvent) {
        window?.isMovable = true
    }
}

struct TabStripContainer<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> TabStripContainerNSView {
        let container = TabStripContainerNSView()
        container.configure(with: AnyView(content))
        return container
    }

    func updateNSView(_ container: TabStripContainerNSView, context: Context) {
        container.configure(with: AnyView(content))
    }
}

private enum ToolbarMetrics {
    static let tabRowHeight: CGFloat = MacDesign.Size.tabStripHeight
    static let toolbarHeight: CGFloat = MacDesign.Size.toolbarRowHeight
    static let trafficLightWidth: CGFloat = MacDesign.Size.trafficLightWidth
    static let trailingPad: CGFloat = MacDesign.Spacing.toolbarPadding
    static let toolbarLeadingPad: CGFloat = MacDesign.Spacing.toolbarPadding
    static let totalHeight: CGFloat = tabRowHeight + MacDesign.Spacing.hairline + toolbarHeight
}

struct BrowserToolbarView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var profileEnvironment: ProfileEnvironment
    @Environment(ProfileManager.self) private var profileManager: ProfileManager
    @Environment(ContentViewModel.self) private var viewModel: ContentViewModel
    @Environment(\.colorScheme) private var colorScheme

    let onNavigate: (String) -> Void

    @State private var isProfileHovered = false
    @State private var addressText = ""
    @State private var isHoveringSuggestions = false
    @State private var isRecentSearchesEligible = false
    @State private var urlBarWidth: CGFloat = 0

    var body: some View {
        topContent
            .frame(maxWidth: .infinity)
            .frame(height: ToolbarMetrics.totalHeight)
            .background(toolbarBackground)
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .top) {
                suggestionsOverlay
            }
    }

    @ViewBuilder
    private var suggestionsOverlay: some View {
        let isFocused = viewModel.isEditingAddressBar
        let hasSuggestions = !viewModel.illuminatePageSuggestions.isEmpty ||
            !viewModel.historySuggestions.isEmpty ||
            !viewModel.webSuggestions.isEmpty
        let showRecentSearches = isFocused && isRecentSearchesEligible && !viewModel.recentSearchSuggestions.isEmpty
        if (isFocused || isHoveringSuggestions) && (hasSuggestions || showRecentSearches) {
            SuggestionsDropdownView(
                tabManager: tabManager,
                themeColor: effectiveThemeColor,
                addressText: $addressText,
                isHoveringSuggestions: $isHoveringSuggestions,
                showRecentSearches: showRecentSearches,
                onNavigate: onNavigate
            )
            .frame(width: urlBarWidth > 0 ? urlBarWidth : nil)
            .offset(y: ToolbarMetrics.totalHeight + MacDesign.Spacing.mini)
        }
    }

    private var theme: BrowserTheme {
        BrowserTheme(accent: effectiveThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    private var effectiveThemeColor: Color {
        profileEnvironment.isGuestSession ? BrowserTheme.guestAccent : tabManager.windowThemeColor
    }

    private var topContent: some View {
        VStack(spacing: 0) {
            tabStripRow
            separatorLine
            navigationRow
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: MacDesign.Spacing.hairline)
        }
    }

    private var tabStripRow: some View {
        HStack(spacing: 0) {
            WindowDragArea()
                .frame(width: tabManager.isFullScreen
                       ? MacDesign.Spacing.control
                       : ToolbarMetrics.trafficLightWidth)

            TabStripContainer {
                TabBarView()
            }
            .frame(maxWidth: .infinity)
            WindowDragArea()
                .frame(width: ToolbarMetrics.trailingPad - MacDesign.Spacing.control)
        }
        .frame(height: ToolbarMetrics.tabRowHeight)
        .background(theme.tabStripBackground)
        .zIndex(10)
    }

    private var separatorLine: some View {
        Rectangle()
            .fill(Color.borderSubtle.opacity(0.45))
            .frame(height: MacDesign.Spacing.hairlineThin)
    }

    private var navigationRow: some View {
        HStack(spacing: MacDesign.Spacing.control) {
            Spacer()
                .frame(width: ToolbarMetrics.toolbarLeadingPad)
            navigationControls
            URLBar(
                activeTab: tabManager.activeTab,
                themeColor: effectiveThemeColor,
                onNavigate: onNavigate,
                addressText: $addressText,
                isHoveringSuggestions: $isHoveringSuggestions,
                isRecentSearchesEligible: $isRecentSearchesEligible
            )
            .onPreferenceChange(URLBarWidthPreferenceKey.self) { urlBarWidth = $0 }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            actionsCluster

            Spacer()
                .frame(width: ToolbarMetrics.trailingPad)
        }
        .frame(height: ToolbarMetrics.toolbarHeight)
    }

    private var actionsCluster: some View {
        HStack(spacing: MacDesign.Spacing.micro) {
            ExtensionToolbarItems()
            DownloadsToolbarButton()
            profileMenu
            MoreOptionsMenu()
        }
    }

    @ViewBuilder
    private var navigationControls: some View {
        if let activeTab = tabManager.activeTab {
            NavigationControls(tab: activeTab, themeColor: effectiveThemeColor, windowThemeColor: tabManager.windowThemeColor)
        } else {
            HStack(spacing: MacDesign.Spacing.hairline) {
                inertNavIcon("chevron.left")
                inertNavIcon("chevron.right")
                inertNavIcon("arrow.clockwise")
            }
            .navClusterBackground()
        }
    }

    private func inertNavIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.webMicroMedium)
            .foregroundStyle(Color.textTertiary)
            .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
    }


    private var profileMenu: some View {
        Menu {
            Section("Switch Profile") {
                ForEach(profileManager.profiles) { profile in
                    Button {
                        DockMenuWindowRouter.shared.openProfile?(profile.id)
                    } label: {
                        Label(profile.name, systemImage: profile.iconName)
                    }
                    .disabled(profile.id == profileEnvironment.profile.id && !profileEnvironment.isGuestSession)
                }
            }

            Section {
                Button {
                    NotificationCenter.default.post(name: .newPrivateWindow, object: nil)
                } label: {
                    Label("New Private Window", systemImage: "eyeglasses")
                }
                Button {
                    DockMenuWindowRouter.shared.openProfileSelection?()
                } label: {
                    Label("Add Profile…", systemImage: "plus.circle")
                }
            }
        } label: {
            Group {
                if profileEnvironment.isGuestSession {
                    Image(systemName: "eyeglasses")
                        .font(.webCaptionBold)
                        .foregroundStyle(BrowserTheme.guestAccent)
                } else {
                    Image(systemName: profileEnvironment.profile.iconName)
                        .font(.webCaptionBold)
                        .foregroundStyle(isProfileHovered ? Color.textPrimary : Color.textSecondary)
                }
            }
            .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
            .macControlBackground(isHovered: isProfileHovered, tint: effectiveThemeColor, radius: MacDesign.Radius.full)
            .contentShape(Circle())
            .animation(MacDesign.fastAnimation, value: isProfileHovered)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { isProfileHovered = $0 }
        .hoverCursor(.pointingHand)
        .help(profileEnvironment.isGuestSession ? "Guest Browsing" : profileEnvironment.profile.name)
        .accessibilityLabel(profileEnvironment.isGuestSession ? "Guest Profile" : profileEnvironment.profile.name)
        .accessibilityIdentifier("browser.toolbar.profileButton")
    }

    private var toolbarBackground: some View {
        Rectangle()
            .fill(theme.windowThemeColor)
            .ignoresSafeArea(edges: .top)
    }

}

private struct SuggestionsDropdownView: View {
    @Environment(ContentViewModel.self) private var viewModel: ContentViewModel
    @Environment(\.colorScheme) private var colorScheme

    let tabManager: TabManager
    let themeColor: Color
    @Binding var addressText: String
    @Binding var isHoveringSuggestions: Bool
    let showRecentSearches: Bool
    let onNavigate: (String) -> Void

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme, windowThemeColor: themeColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacDesign.Spacing.micro) {
            if addressText.isEmpty && showRecentSearches {
                Text("Recent Searches")
                    .font(.webMicroMedium)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.leading, MacDesign.Spacing.small)
                ForEach(viewModel.recentSearchSuggestions, id: \.self) { query in
                    WebSuggestionRowView(text: query, accentColor: themeColor) {
                        selectWebSuggestion(query)
                    }
                }
            }

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
        .accessibilityLabel("Search suggestions")
        .onHover { hovering in
            isHoveringSuggestions = hovering
        }
    }

    private func selectIlluminatePageSuggestion(_ suggestion: IlluminatePageSuggestion) {
        isHoveringSuggestions = false
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
        viewModel.setAddressBarEditing(false)
        viewModel.cancelSuggestions()
        onNavigate(suggestion.urlString)
    }

    private func selectWebSuggestion(_ suggestion: String) {
        addressText = suggestion
        isHoveringSuggestions = false
        viewModel.setAddressBarEditing(false)
        viewModel.cancelSuggestions()
        onNavigate(suggestion)
    }
}