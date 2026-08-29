//
//  ThemePresetPalette.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import SwiftUI

struct ThemePresetPalette: View {
    @Binding var theme: IlluminateTheme
    @Binding var selectedColorID: UUID?

    static let presets: [Color] = [
        Color(hex: "#F4EFDF"),
        Color(hex: "#F0B8CD"),
        Color(hex: "#E9C3E3"),
        Color(hex: "#DA7682"),
        Color(hex: "#EB8570"),
        Color(hex: "#DCCE7F"),
        Color(hex: "#5BECAD"),
        Color(hex: "#919BB5")
    ]

    @State private var selectedPresetIndex: Int?
    @State private var currentCombo: PaletteCombo = .normal

    enum PaletteCombo: Int, CaseIterable {
        case normal
        case light
        case dark
        case gray

        var title: String {
            switch self {
            case .normal: return "Normal"
            case .light:  return "Light"
            case .dark:   return "Dark"
            case .gray:   return "Gray"
            }
        }
    }

    private var currentPresets: [Color] {
        switch currentCombo {
        case .normal:
            return Self.presets
        case .light:
            return Self.presets.map { color in
                let hsl = color.resolvedHSL
                return ThemeColorMath.hslToColor(h: hsl.h, s: min(1, hsl.s * 0.4), l: min(1, hsl.l + 0.35))
            }
        case .dark:
            return Self.presets.map { color in
                let hsl = color.resolvedHSL
                return ThemeColorMath.hslToColor(h: hsl.h, s: hsl.s, l: max(0, hsl.l - 0.25))
            }
        case .gray:
            return (0..<8).map { i in
                let brightness = Double(i) / 7.0
                return Color(white: brightness)
            }
        }
    }

    private let swatchSize: CGFloat = 30
    private let swatchSpacing: CGFloat = 14

    var body: some View {
        HStack(spacing: 10) {
            pagingButton(systemImage: "chevron.left") {
                cycleCombo(forward: false)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: swatchSpacing) {
                    ForEach(Array(currentPresets.enumerated()), id: \.offset) { index, color in
                        swatch(color: color, index: index)
                    }
                }
                .padding(.horizontal, 2) // room for the selection ring to render without clipping
            }
            .frame(maxWidth: .infinity)

            pagingButton(systemImage: "chevron.right") {
                cycleCombo(forward: true)
            }
        }
    }

    private func swatch(color: Color, index: Int) -> some View {
        let isSelected = selectedPresetIndex == index

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedPresetIndex = index
                applyPreset(color)
            }
        } label: {
            Circle()
                .fill(color)
                .frame(width: swatchSize, height: swatchSize)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
                        .padding(-3)
                )
                .scaleEffect(isSelected ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Preset color \(index + 1)"))
    }

    private func pagingButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    private func cycleCombo(forward: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            let all = PaletteCombo.allCases
            let current = currentCombo.rawValue
            let next = forward ? (current + 1) % all.count : (current - 1 + all.count) % all.count
            currentCombo = all[next]
            selectedPresetIndex = nil
        }
    }

    private func applyPreset(_ color: Color) {
        guard let id = selectedColorID,
              let index = theme.colors.firstIndex(where: { $0.id == id }) else { return }

        let resolved = color.resolvedHSL
        theme.colors[index].hue = resolved.h
        theme.colors[index].saturation = resolved.s
        theme.colors[index].lightness = resolved.l
        theme.colors[index].position = ThemeColorMath.colorToPoint(hue: resolved.h, saturation: resolved.s)
    }
}

#Preview {
    ThemePresetPalette(theme: .constant(.default), selectedColorID: .constant(nil))
        .padding(40)
        .background(Color.black)
}
