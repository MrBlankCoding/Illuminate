//
//  TabHoverPreview.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI

@MainActor
struct TabPipInlineAffordance: View {
    let tab: Tab
    let themeColor: Color
    let isActive: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            tab.togglePictureInPicture()
        } label: {
            Image(systemName: tab.hasPiPCandidate ? "pip.enter" : "pip.exit")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isActive ? themeColor : Color.textSecondary)
                .frame(width: 16, height: 16)
                .background(Color.primary.opacity(isHovered ? 0.10 : 0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .hoverCursor(.pointingHand)
        .help(tab.hasPiPCandidate ? "Enter Picture in Picture" : "Exit Picture in Picture")
        .accessibilityLabel("Picture in Picture")
    }
}


@MainActor
struct TabHoverPreview: View {
    let tab: Tab
    let themeColor: Color
    var onTogglePiP: (() -> Void)? = nil
    var onKeepAlive: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    private var subtitle: String {
        if let host = tab.url?.host, !host.isEmpty {
            return host
        }
        if let urlString = tab.url?.absoluteString, !urlString.isEmpty {
            return urlString
        }
        return "about:blank"
    }

    var body: some View {
        HStack(alignment: .top, spacing: MacDesign.Spacing.medium) {
            favicon

            VStack(alignment: .leading, spacing: MacDesign.Spacing.tiny) {
                Text(tab.title.isEmpty ? "New Tab" : tab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.webSmall)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if tab.hasPiPCandidate {
                Button {
                    tab.togglePictureInPicture()
                    onTogglePiP?()
                } label: {
                    Label("PiP", systemImage: "pip.enter")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(themeColor)
                .fixedSize()
                .layoutPriority(2)
            }
        }
        .padding(.horizontal, MacDesign.Spacing.regular)
        .padding(.vertical, MacDesign.Spacing.medium)
        .fixedSize(horizontal: false, vertical: true)
        .floatingGlassPanel(cornerRadius: MacDesign.Radius.card)
        .compositingGroup()
        .onHover { hovering in
            hovering ? onKeepAlive?() : onDismiss?()
        }
    }

    private var favicon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MacDesign.Radius.groupHeader, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .frame(width: MacDesign.Size.largeIconButton, height: MacDesign.Size.largeIconButton)

            if let img = tab.favicon {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .fixedSize()
    }
}