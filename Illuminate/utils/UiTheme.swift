//
//  UiTheme.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/10/26.
//

import SwiftUI

extension Color {
    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary
    static let borderSubtle  = Color.primary.opacity(0.08)
    static let accentBeam    = Color.accentColor
    static let accentSoft    = Color.accentColor.opacity(0.15)
}

struct BrowserTheme {
    let accent: Color
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }
    var windowBase: Color {
        isDark ? Color(hex: "101216") : Color(hex: "F8F9FB")
    }

    var itemHover: Color  { accent.opacity(isDark ? 0.10 : 0.08) }
    var itemActive: Color { accent.opacity(isDark ? 0.18 : 0.14) }
    var selectionIndicator: Color { accent }
    var textOnAccent: Color { isDark ? .white : .black }
}

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
            }
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: Capsule())
            .background {
                if let tint {
                    Capsule().fill(tint.opacity(0.12))
                }
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 8) -> some View {
        modifier(GlassModifier(cornerRadius: cornerRadius))
    }

    func liquidGlassCapsule(tint: Color? = nil, padding: CGFloat = 0) -> some View {
        modifier(LiquidGlassCapsuleModifier(tint: tint, padding: padding))
    }

    @ViewBuilder
    func browserPanel(cornerRadius: CGFloat = 10) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    func insetPanel(cornerRadius: CGFloat = 8) -> some View {
        self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    func accentGlassPanel(accent: Color, cornerRadius: CGFloat = 10) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accent.opacity(0.14))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    func floatingGlassPanel(cornerRadius: CGFloat = 10) -> some View {
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    func focusRing(_ active: Bool) -> some View {
        modifier(FocusRingModifier(isActive: active))
    }

    func hoverCursor(_ cursor: NSCursor) -> some View {
        modifier(HoverCursorModifier(cursor: cursor))
    }
}

struct GlassButtonStyle: ButtonStyle {
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.webBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background {
                if let tint {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint.opacity(0.12))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GlassToggleStyle: ToggleStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                
                if configuration.isOn {
                    Capsule()
                        .fill(tint.opacity(0.2))
                }

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .padding(2)
            }
            .frame(width: 36, height: 20)
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    configuration.isOn.toggle()
                }
            }
            .hoverCursor(.pointingHand)
        }
    }
}

struct LiquidGlassGroup<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}

struct GlassEffectIDModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        content
    }
}

struct FocusRingModifier: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.accentBeam.opacity(0.6) : .clear, lineWidth: 3)
            )
            .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

private struct HoverCursorModifier: ViewModifier {
    let cursor: NSCursor
    func body(content: Content) -> some View {
        content.onHover { hovering in
            hovering ? cursor.push() : NSCursor.pop()
        }
    }
}

struct CavedDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 1)
            .opacity(0.4)
            .padding(.vertical, 2)
    }
}

extension Font {
    static let webH1   = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let webH2   = Font.system(size: 20, weight: .medium,   design: .rounded)
    static let webBody = Font.system(size: 14)
    static let webMicro = Font.system(size: 12)
}

extension Animation {
    static var browserDefault: Animation {
        .spring(response: 0.3, dampingFraction: 0.8)
    }
}

extension Color {

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    func toHex() -> String? {
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB)
            ?? NSColor(self).usingColorSpace(.sRGB)
        else {
            return nil
        }

        let r = Float(nsColor.redComponent)
        let g = Float(nsColor.greenComponent)
        let b = Float(nsColor.blueComponent)
        let a = Float(nsColor.alphaComponent)
        if a < 1 {
            return String(format: "%02lX%02lX%02lX%02lX",
                          lroundf(r*255), lroundf(g*255), lroundf(b*255), lroundf(a*255))
        }
        return String(format: "%02lX%02lX%02lX",
                      lroundf(r*255), lroundf(g*255), lroundf(b*255))
    }

    func hexString() -> String { toHex() ?? "#FFFFFF" }

    func blended(with color: Color, fraction: CGFloat) -> Color {
        let lhs = NSColor(self).usingColorSpace(.deviceRGB) ?? .white
        let rhs = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        return Color(lhs.blended(withFraction: fraction, of: rhs) ?? lhs)
    }
}

extension AngularGradient {
    static var colorfulAngularGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: stride(from: 0, through: 360, by: 60).map {
                Color(hue: Double($0) / 360, saturation: 1, brightness: 1)
            }),
            center: .center
        )
    }
}
