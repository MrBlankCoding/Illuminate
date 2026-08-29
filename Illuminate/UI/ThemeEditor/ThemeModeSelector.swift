//
//  ThemeModeSelector.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct ThemeModeSelector: View {
    @Binding var scheme: ThemeScheme

    @Namespace private var selectionNamespace
    private let itemSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 14) {
            modeButton(.automatic, systemImage: "sparkles")
            modeButton(.light, systemImage: "sun.max.fill")
            modeButton(.dark, systemImage: "moon.stars.fill")
        }
    }

    private func modeButton(_ mode: ThemeScheme, systemImage: String) -> some View {
        let isSelected = scheme == mode

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                scheme = mode
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .matchedGeometryEffect(id: "modeSelection", in: selectionNamespace)
                }

                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                    .scaleEffect(isSelected ? 1.0 : 0.92)
            }
            .frame(width: itemSize, height: itemSize)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mode.rawValue.capitalized))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    ThemeModeSelector(scheme: .constant(.automatic))
        .padding(40)
        .background(Color.black)
}
