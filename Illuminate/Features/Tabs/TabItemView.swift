//
//  TabItemView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

private enum TabItemMetrics {
    static let titleThreshold: CGFloat = 72
    static let height: CGFloat = 34
    static let cornerRadius: CGFloat = MacDesign.Radius.control
    static let closeButtonSize: CGFloat = 18
    static let hPad: CGFloat = 8
    static let closeReserve: CGFloat = 22
    static let progressHeight: CGFloat = 2
    static let separatorHeight: CGFloat = 12.5
}

struct TabItemView: View {
    @ObservedObject var tab: Tab

    let themeColor: Color
    let isActive: Bool
    let showsTrailingSeparator: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void
    let onDuplicate: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void
    let onCopyLink: () -> Void
    let onToggleMute: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var tabManager: TabManager
    
    @State private var isHovered = false
    @State private var isCloseHovered = false

    private var showClose: Bool { isHovered || isActive }

    private var theme: BrowserTheme {
        BrowserTheme(accent: themeColor, colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Button(action: onSelect) {
                    HStack(spacing: 5) {
                        faviconArea

                        if geo.size.width >= TabItemMetrics.titleThreshold {
                            titleLabel
                        }

                        if showClose {
                            Spacer(minLength: TabItemMetrics.closeReserve)
                        }
                    }
                    .padding(.horizontal, TabItemMetrics.hPad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tabBackground)
                    .contentShape(
                        RoundedRectangle(
                            cornerRadius: TabItemMetrics.cornerRadius,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(TabPressButtonStyle())
                .accessibilityLabel(tab.title.isEmpty ? "New Tab" : tab.title)
                .accessibilityIdentifier("browser.tabbar.tab")
                .accessibilityAddTraits(isActive ? [.isSelected] : [])

                if showClose {
                    closeButton
                        .padding(.trailing, 5)
                        .transition(.opacity)
                        .zIndex(1)
                }

                if tab.isLoading && tab.estimatedProgress < 1.0 {
                    loadingIndicator
                        .transition(.opacity.animation(MacDesign.fastAnimation))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: TabItemMetrics.height)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: TabItemMetrics.cornerRadius,
                    style: .continuous
                )
            )
        }
        .frame(height: TabItemMetrics.height)
        .overlay(alignment: .trailing) {
            if showsTrailingSeparator {
                Rectangle()
                    .fill(Color.white.opacity(isActive ? 0.50 : 0.38))
                    .frame(width: 1, height: TabItemMetrics.separatorHeight)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(MacDesign.fastAnimation) { isHovered = hovering }
        }
        .hoverCursor(.pointingHand)
        .contextMenu { contextMenuItems }
    }

    @ViewBuilder
    private var faviconArea: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if tab.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(isActive ? themeColor : Color.textSecondary)
                } else {
                    faviconImage
                }
            }
            .frame(width: 16, height: 16)
            if tab.isMuted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(1.5)
                    .background(Color.secondary.opacity(0.85), in: Circle())
                    .offset(x: 4, y: 4)
            }
        }
        .frame(width: 16, height: 16)
        .animation(MacDesign.fastAnimation, value: tab.isLoading)
        .animation(MacDesign.fastAnimation, value: tab.isMuted)
    }

    @ViewBuilder
    private var faviconImage: some View {
        if let image = tab.favicon {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else if let url = tab.url, let page = IlluminatePage(url: url) {
            Image(systemName: page.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? themeColor : Color.textSecondary)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "globe")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? themeColor : Color.textSecondary)
                .frame(width: 16, height: 16)
        }
    }

    private var titleLabel: some View {
        Text(tab.title.isEmpty ? "New Tab" : tab.title)
            .font(.system(size: 12, weight: isActive ? .medium : .regular))
            .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isActive {
            RoundedRectangle(cornerRadius: TabItemMetrics.cornerRadius, style: .continuous)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: TabItemMetrics.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: TabItemMetrics.cornerRadius, style: .continuous)
                        .fill(themeColor.opacity(colorScheme == .dark ? 0.14 : 0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: TabItemMetrics.cornerRadius, style: .continuous)
                        .stroke(
                            themeColor.opacity(colorScheme == .dark ? 0.26 : 0.20),
                            lineWidth: 0.75
                        )
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10),
                    radius: 6,
                    y: 2
                )
                .matchedGeometryEffect(id: "activeTabBackground", in: namespace)
                .transition(.opacity)
        } else if isHovered {
            RoundedRectangle(cornerRadius: TabItemMetrics.cornerRadius, style: .continuous)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: TabItemMetrics.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: TabItemMetrics.cornerRadius, style: .continuous)
                        .fill(theme.itemHover)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: TabItemMetrics.cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.14 : 0.05),
                    radius: 3,
                    y: 1
                )
                .transition(.opacity)
        } else {
            Color.clear
        }
    }

    private var loadingIndicator: some View {
        VStack {
            Spacer()
            // Progress animates via scaleEffect (GPU-composited transform)
            // instead of frame(width:), so each 100ms progress tick never
            // triggers a layout pass. No shadow — it would re-rasterize
            // every frame.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [themeColor.opacity(0.55), themeColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: TabItemMetrics.progressHeight)
                .scaleEffect(
                    x: max(tab.estimatedProgress, 0.002),
                    y: 1,
                    anchor: .leading
                )
                .animation(.easeOut(duration: 0.25), value: tab.estimatedProgress)
        }
        .padding(.horizontal, TabItemMetrics.hPad - 2)
        .padding(.bottom, 4)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(
                        isCloseHovered
                            ? Color.red.opacity(0.16)
                            : Color.primary.opacity(isActive ? 0.09 : 0.06)
                    )
                    .frame(
                        width: TabItemMetrics.closeButtonSize,
                        height: TabItemMetrics.closeButtonSize
                    )
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(isCloseHovered ? Color.red : Color.textSecondary)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isCloseHovered = $0 }
        .hoverCursor(.pointingHand)
        .help("Close Tab")
        .accessibilityLabel("Close \(tab.title.isEmpty ? "New Tab" : tab.title)")
        .accessibilityIdentifier("browser.tabbar.closeTabButton")
        .animation(MacDesign.fastAnimation, value: isCloseHovered)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("New Tab") {
            NotificationCenter.default.post(name: .newTab, object: nil)
        }

        Divider()

        Button("Reload Tab") { tab.reload() }
            .disabled(tab.url == nil)

        Button("Duplicate Tab") { onDuplicate() }
            .disabled(tab.url == nil)

        Button(tab.isMuted ? "Unmute Tab" : "Mute Tab") { onToggleMute() }

        Divider()

        Button("Copy Link") { onCopyLink() }
            .disabled(tab.url == nil)

        Divider()

        Menu("Move to Group") {
            Button("New Group") {
                NotificationCenter.default.post(name: .newTabGroup, object: nil)
            }
            if let tabManager = getTabManager(), !tabManager.tabGroupManager.groups.isEmpty {
                Divider()
                ForEach(tabManager.tabGroupManager.groups) { group in
                    Button {
                        tabManager.tabGroupManager.moveTabToGroup(tab.id, targetGroupID: group.id)
                    } label: {
                        HStack {
                            Circle()
                                .fill(group.groupColor.color)
                                .frame(width: 10, height: 10)
                            Text(group.name.isEmpty ? "Unnamed Group" : group.name)
                        }
                    }
                }
            }
        }
        
        if let tabManager = getTabManager(), tabManager.tabGroupManager.group(for: tab.id) != nil {
            Button("Remove from Group") {
                tabManager.tabGroupManager.removeTabFromGroup(tab.id)
            }
        }

        Divider()

        Button("Close Other Tabs") { onCloseOthers() }
        Button("Close Tabs to the Right") { onCloseToRight() }

        Divider()

        Button("Close Tab", role: .destructive) { onClose() }
    }
    
    private func getTabManager() -> TabManager? {
        return tabManager
    }
}

private struct TabPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
