//
//  UiTheme.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/10/26.
//

import SwiftUI

extension Color {
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let borderSubtle = Color.primary.opacity(0.10)
    static let accentBeam = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.14)
}

struct BrowserTheme {
    let accent: Color
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }

    var windowBase: Color {
        isDark ? Color(hex: "161617") : Color(hex: "F5F5F7")
    }

    var toolbarBase: Color { isDark ? Color.white.opacity(0.045) : Color.white.opacity(0.56) }
    var sidebarBase: Color { isDark ? Color.white.opacity(0.035) : Color.white.opacity(0.42) }
    var pageBase: Color { isDark ? Color(hex: "1C1C1E") : Color.white }
    var itemHover: Color { isDark ? Color.white.opacity(0.075) : Color.black.opacity(0.055) }
    var itemActive: Color { accent.opacity(isDark ? 0.22 : 0.16) }
    var separator: Color { isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.10) }
    var controlFill: Color { isDark ? Color.white.opacity(0.075) : Color.white.opacity(0.72) }
    var elevatedFill: Color { isDark ? Color.white.opacity(0.09) : Color.white.opacity(0.88) }
    var selectionIndicator: Color { accent }
    var textOnAccent: Color { .white }
}

enum MacDesign {
    enum Radius {
        static let small: CGFloat = 7
        static let control: CGFloat = 10
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let panel: CGFloat = 20
    }

    enum Spacing {
        static let hairline: CGFloat = 1
        static let tight: CGFloat = 6
        static let control: CGFloat = 8
        static let regular: CGFloat = 12
        static let roomy: CGFloat = 16
        static let section: CGFloat = 20
        static let page: CGFloat = 24
    }

    enum Size {
        static let iconButton: CGFloat = 28
        static let largeIconButton: CGFloat = 32
        static let urlBarHeight: CGFloat = 34
        static let tabHeight: CGFloat = 34
        static let tabStripHeight: CGFloat = 42
        static let toolbarRowHeight: CGFloat = 48
    }

    static let fastAnimation = Animation.easeInOut(duration: 0.16)
    static let springAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)
}

struct MacMaterialModifier: ViewModifier {
    var cornerRadius: CGFloat = MacDesign.Radius.medium
    var style: Glass = .regular
    var strokeOpacity: Double = 0.10
    var shadowOpacity: Double = 0.0

    func body(content: Content) -> some View {
        content
            .glassEffect(style, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(strokeOpacity), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowOpacity > 0 ? 18 : 0, y: shadowOpacity > 0 ? 10 : 0)
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glassEffect(.regular, in: .capsule)
            .background {
                if let tint {
                    Capsule().fill(tint.opacity(0.10))
                }
            }
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 8) -> some View {
        modifier(MacMaterialModifier(cornerRadius: cornerRadius, style: .regular, strokeOpacity: 0.10))
    }

    func liquidGlassCapsule(tint: Color? = nil, padding: CGFloat = 0) -> some View {
        modifier(LiquidGlassCapsuleModifier(tint: tint, padding: padding))
    }

    @ViewBuilder
    func browserPanel(cornerRadius: CGFloat = 10) -> some View {
        self.modifier(MacMaterialModifier(cornerRadius: cornerRadius, style: .regular, strokeOpacity: 0.09))
    }

    @ViewBuilder
    func insetPanel(cornerRadius: CGFloat = 8) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    func accentGlassPanel(accent: Color, cornerRadius: CGFloat = 10) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accent.opacity(0.13))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    func floatingGlassPanel(cornerRadius: CGFloat = 10) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    func macPopover(cornerRadius: CGFloat = MacDesign.Radius.large) -> some View {
        modifier(MacMaterialModifier(cornerRadius: cornerRadius, style: .regular, strokeOpacity: 0.10, shadowOpacity: 0.16))
    }

    func macControlBackground(isActive: Bool = false, isHovered: Bool = false, tint: Color? = nil, radius: CGFloat = MacDesign.Radius.control) -> some View {
        modifier(MacControlBackgroundModifier(isActive: isActive, isHovered: isHovered, tint: tint, radius: radius))
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
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: MacDesign.Radius.control))
            .background {
                if let tint {
                    RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous)
                        .fill(tint.opacity(0.11))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
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
            Toggle("", isOn: configuration.$isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tint)
        }
    }
}

struct LiquidGlassGroup<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
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
                RoundedRectangle(cornerRadius: MacDesign.Radius.control)
                    .stroke(isActive ? Color.accentBeam.opacity(0.34) : .clear, lineWidth: 3)
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
            .opacity(0.7)
    }
}

extension Font {
    static let webH1   = Font.system(size: 24, weight: .semibold)
    static let webH2   = Font.system(size: 20, weight: .medium)
    static let webBody = Font.system(size: 14)
    static let webMicro = Font.system(size: 12.5)
}

extension Animation {
    static var browserDefault: Animation {
        MacDesign.springAnimation
    }
}

struct ToolbarIconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct MacToolbarButtonStyle: ButtonStyle {
    var isActive = false
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
            .glassEffect(isActive ? .regular : .regular.interactive(), in: .circle)
            .background {
                if isActive || configuration.isPressed {
                    Circle()
                        .fill((tint ?? .accentColor).opacity(0.18))
                }
            }
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(MacDesign.fastAnimation, value: configuration.isPressed)
    }
}

private struct MacControlBackgroundModifier: ViewModifier {
    let isActive: Bool
    let isHovered: Bool
    let tint: Color?
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(stroke, lineWidth: 0.5)
            }
    }

    private var fill: Color {
        if isActive, let tint {
            return tint.opacity(0.16)
        }
        if isActive {
            return Color.primary.opacity(0.08)
        }
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        return Color.clear
    }

    private var stroke: Color {
        if isActive, let tint {
            return tint.opacity(0.24)
        }
        return isHovered || isActive ? Color.primary.opacity(0.10) : Color.clear
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
