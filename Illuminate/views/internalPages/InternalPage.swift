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
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accentColor.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }

                    Text(title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                }

                content()
            }
            .padding(32)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct InternalPageRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct InternalPageChipButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.22 : 0.12),
                        in: Capsule())
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct InternalPageEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
