//
//  BrowserToolbarView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//


import SwiftUI
import AppKit

struct TabFramesKey: PreferenceKey {
    typealias Value = [UUID: CGRect]
    static var defaultValue: Value { [:] }

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { _, new in new }
    }
}



final class TopContainerNSView: NSView {
    var tabFrames: [UUID: CGRect] = [:]
    override var isFlipped: Bool { true }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let hitTab = tabFrames.values.contains { $0.contains(localPoint) }
        if hitTab {
            super.mouseDown(with: event)
        } else {
            window?.performDrag(with: event)
        }
    }
}

struct TopHostView<Content: View>: NSViewRepresentable {

    let content: Content
    let tabFrames: [UUID: CGRect]

    init(tabFrames: [UUID: CGRect], @ViewBuilder content: () -> Content) {
        self.tabFrames = tabFrames
        self.content = content()
    }

    func makeNSView(context: Context) -> TopContainerNSView {
        let container = TopContainerNSView()
        container.wantsLayer = true

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = container.bounds
        hosting.safeAreaRegions = []
        container.addSubview(hosting)
        return container
    }

    func updateNSView(_ container: TopContainerNSView, context: Context) {
        container.tabFrames = tabFrames
        guard let hosting = container.subviews.first as? NSHostingView<Content> else { return }
        hosting.rootView = content
    }
}

private enum ToolbarMetrics {
    static let tabRowHeight: CGFloat = 42
    static let toolbarHeight: CGFloat = 48
    static let trafficLightWidth: CGFloat = 78
    static let trailingPad: CGFloat = 14
    static let toolbarLeadingPad: CGFloat = 14
    static let totalHeight: CGFloat = tabRowHeight + 1 + toolbarHeight
}

struct BrowserToolbarView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var profileEnvironment: ProfileEnvironment
    @EnvironmentObject private var profileManager: ProfileManager
    @Environment(\.colorScheme) private var colorScheme

    @Binding var addressBarText: String
    let onNavigate: () -> Void

    @State private var tabFrames: [UUID: CGRect] = [:]
    @State private var isProfileHovered = false

    // gonna need to work on the spacing here
    private var theme: BrowserTheme {
        let accent = profileEnvironment.isGuestSession
            ? Color(hex: "7B52CC")
            : tabManager.windowThemeColor
        return BrowserTheme(accent: accent, colorScheme: colorScheme)
    }

    private var effectiveThemeColor: Color {
        profileEnvironment.isGuestSession ? Color(hex: "7B52CC") : tabManager.windowThemeColor
    }

    var body: some View {
        topContent
            .frame(maxWidth: .infinity)
            .frame(height: ToolbarMetrics.totalHeight)
            .background(toolbarBackground)
            .ignoresSafeArea(edges: .top)
            .onPreferenceChange(TabFramesKey.self) { frames in
                tabFrames = frames
            }
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
                .fill(theme.separator)
                .frame(height: 1)
        }
        .coordinateSpace(name: "top")
    }

    private var tabStripRow: some View {
        TopHostView(tabFrames: tabFrames) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: tabManager.isFullScreen
                           ? 8
                           : ToolbarMetrics.trafficLightWidth)

                TabBarView()
                    .frame(maxWidth: .infinity)
                Color.clear
                    .frame(width: ToolbarMetrics.trailingPad - 8)
            }
            .frame(height: ToolbarMetrics.tabRowHeight)
        }
        .frame(height: ToolbarMetrics.tabRowHeight)
    }

    private var separatorLine: some View {
        Rectangle()
            .fill(theme.separator.opacity(0.45))
            .frame(height: 0.5)
    }

    private var navigationRow: some View {
        HStack(spacing: 10) {
            Spacer()
                .frame(width: ToolbarMetrics.toolbarLeadingPad)
            navigationControls
            URLBar(
                activeTab: tabManager.activeTab,
                addressText: $addressBarText,
                themeColor: effectiveThemeColor,
                onNavigate: onNavigate
            )
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            actionsCluster

            Spacer()
                .frame(width: ToolbarMetrics.trailingPad)
        }
        .frame(height: ToolbarMetrics.toolbarHeight)
    }

    private var actionsCluster: some View {
        HStack(spacing: 2) {
            ExtensionToolbarItems()
            DownloadsToolbarButton()
            profileMenu
            MoreOptionsMenu()
        }
    }

    @ViewBuilder
    private var navigationControls: some View {
        if let activeTab = tabManager.activeTab {
            NavigationControls(tab: activeTab, themeColor: tabManager.windowThemeColor)
        } else {
            HStack(spacing: 1) {
                inertNavIcon("chevron.left")
                inertNavIcon("chevron.right")
                inertNavIcon("arrow.clockwise")
            }
            .navClusterBackground()
        }
    }

    private func inertNavIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.textSecondary.opacity(0.28))
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "7B52CC"))
                } else {
                    Image(systemName: profileEnvironment.profile.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isProfileHovered ? Color.textPrimary : Color.textSecondary)
                }
            }
            .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
            .macControlBackground(isHovered: isProfileHovered, tint: effectiveThemeColor, radius: 999)
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
            .fill(.bar)
            .background(theme.toolbarBase)
            .ignoresSafeArea(edges: .top)
    }

}