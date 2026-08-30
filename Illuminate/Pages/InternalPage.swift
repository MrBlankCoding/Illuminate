//
//  InternalPage.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

struct InternalPage<Content: View>: View {
    let icon: String
    let title: String
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacDesign.Spacing.pageHeaderPadding) {
                HStack(spacing: MacDesign.Spacing.toolbarPadding) {
                    ZStack {
                        RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous)
                            .fill(accentColor.opacity(0.18))
                            .frame(width: MacDesign.Size.toolbarRowHeight, height: MacDesign.Size.toolbarRowHeight)
                        Image(systemName: icon)
                            .font(.webInternalPageIcon)
                            .foregroundStyle(accentColor)
                    }

                    Text(title)
                        .font(.webInternalPageTitle)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityIdentifier("browser.internalPage.\(title.lowercased())")
                }

                content()
            }
            .padding(MacDesign.Spacing.pageHeaderPadding)
            .frame(maxWidth: MacDesign.Size.internalPageMax, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct InternalPageRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, MacDesign.Spacing.roomy)
            .padding(.vertical, MacDesign.Spacing.toolbarPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
    }
}

struct InternalPageChipButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.webMicroMedium.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, MacDesign.Spacing.regular)
            .padding(.vertical, MacDesign.Spacing.tight)
            .background(color.opacity(configuration.isPressed ? 0.22 : 0.12),
                        in: Capsule())
            .animation(MacDesign.fastAnimation, value: configuration.isPressed)
    }
}

struct InternalPageEmptyState: View {
    let icon: String
    let message: String
    var subtitle: String? = nil
    var verticalPadding: CGFloat = MacDesign.Size.toolbarRowHeight

    var body: some View {
        VStack(spacing: MacDesign.Spacing.regular) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.webBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.webMicro)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
    }
}

struct InternalPageSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.webCaptionBold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(MacDesign.Spacing.hairlineThin)
    }
}
