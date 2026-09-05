//
//  UiTheme.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/10/26.
//

import SwiftUI

struct ThemeColor: Codable, Identifiable {
    var id = UUID()
    var hue: Double
    var saturation: Double
    var lightness: Double
    var position: CGPoint

    var color: Color {
        Color.AppColor.hsl(h: hue, s: saturation, l: lightness)
    }
}

enum ThemeScheme: String, Codable, CaseIterable {
    case dark, light, system

    func toUIStyle() -> TabManager.UIStyle {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return .system
        }
    }

    static func fromUIStyle(_ style: TabManager.UIStyle) -> ThemeScheme {
        switch style {
        case .dark: return .dark
        case .light: return .light
        case .system: return .system
        }
    }
}

struct IlluminateTheme: Codable {
    var colors: [ThemeColor]
    var colorScheme: ThemeScheme

    static var `default`: IlluminateTheme {
        IlluminateTheme(
            colors: [ThemeColor(hue: 0, saturation: 0, lightness: 0.5, position: .zero)],
            colorScheme: .system
        )
    }
}

struct ThemeColorMath {
    static func colorToPoint(hue: Double, saturation: Double) -> CGPoint {
        // Simple mapping for theme picker
        return CGPoint(x: hue, y: saturation)
    }
}

extension Color {
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.primary.opacity(0.28)
    static let textQuaternary = Color.primary.opacity(0.18)
    static let borderSubtle = Color.primary.opacity(0.10)
    static let accentBeam = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.14)
    static let suggestionRowHover = Color.primary.opacity(0.07)

    enum AppColor {
        static func hsl(h: Double, s: Double, l: Double, opacity: Double = 1.0) -> Color {
            let h = (h.truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0)
            let s = max(0.0, min(1.0, s))
            let l = max(0.0, min(1.0, l))

            let chroma = (1.0 - abs(2.0 * l - 1.0)) * s
            let x = chroma * (1.0 - abs((h * 6.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
            let m = l - chroma / 2.0

            let (r, g, b): (Double, Double, Double)
            switch Int(floor(h * 6.0)) % 6 {
            case 0: (r, g, b) = (chroma, x, 0)
            case 1: (r, g, b) = (x, chroma, 0)
            case 2: (r, g, b) = (0, chroma, x)
            case 3: (r, g, b) = (0, x, chroma)
            case 4: (r, g, b) = (x, 0, chroma)
            default: (r, g, b) = (chroma, 0, x)
            }

            return Color(red: r + m, green: g + m, blue: b + m, opacity: opacity)
        }

        static func hsb(h: Double, s: Double, b: Double, opacity: Double = 1.0) -> Color {
            Color(hue: h, saturation: s, brightness: b, opacity: opacity)
        }

        static func hslComponents(of color: Color) -> (h: Double, s: Double, l: Double) {
            guard let nsColor = NSColor(color).usingColorSpace(.deviceRGB)
                ?? NSColor(color).usingColorSpace(.sRGB)
            else { return (0, 0, 0.5) }

            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

            let l = (2.0 - s) * b / 2.0
            var sL = s * b / (l < 0.5 ? (l * 2.0) : (2.0 - l * 2.0))
            if sL.isNaN { sL = 0 }
            return (Double(h), Double(sL), Double(l))
        }

        static func hsbComponents(of color: Color) -> (h: Double, s: Double, b: Double) {
            guard let nsColor = NSColor(color).usingColorSpace(.deviceRGB)
                ?? NSColor(color).usingColorSpace(.sRGB)
            else { return (0, 0, 0.5) }

            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return (Double(h), Double(s), Double(b))
        }
    }
}

struct BrowserTheme {
    let accent: Color
    let colorScheme: ColorScheme
    let windowThemeColor: Color

    var isDark: Bool { colorScheme == .dark }

    var windowBase: Color {
        isDark ? Color(hex: "161617") : Color(hex: "F5F5F7")
    }

    var toolbarBase: Color { windowThemeColor }
    var sidebarBase: Color { windowThemeColor }
    var tabStripBackground: Color { windowThemeColor.slightlyDarker }
    var pageBase: Color { isDark ? Color(hex: "1C1C1E") : Color.white }
    var itemHover: Color { isDark ? Color.white.opacity(0.075) : Color.black.opacity(0.055) }
    var itemActive: Color { accent.opacity(isDark ? 0.22 : 0.16) }
    var separator: Color { isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.10) }
    var controlFill: Color { isDark ? Color.white.opacity(0.075) : Color.white.opacity(0.72) }
    var elevatedFill: Color { isDark ? Color.white.opacity(0.09) : Color.white.opacity(0.88) }
    var selectionIndicator: Color { accent }
    var textOnAccent: Color { .white }
    var guestAccent: Color { Color(hex: "7B52CC") }
}

enum BrowserAppearanceSettings {
    static let compactModeKey = "appearance.compactMode"
    static let animationsEnabledKey = "appearance.animationsEnabled"
}

enum MacDesign {
    enum Radius {
        static let micro: CGFloat = 4
        static let mini: CGFloat = 5
        static let groupHeader: CGFloat = 6
        static let small: CGFloat = 7
        static let control: CGFloat = 10
        static let medium: CGFloat = 12
        static let card: CGFloat = 14
        static let large: CGFloat = 16
        static let panel: CGFloat = 20
        static let urlBar: CGFloat = 11
        static let full: CGFloat = 999
    }

    enum Spacing {
        static let hairlineThin: CGFloat = 0.5
        static let hairline: CGFloat = 1
        static let micro: CGFloat = 2
        static let tiny: CGFloat = 3
        static let small: CGFloat = 4
        static let mini: CGFloat = 5
        static let tight: CGFloat = 6
        static let control: CGFloat = 8
        static let medium: CGFloat = 10
        static let regular: CGFloat = 12
        static let toolbarPadding: CGFloat = 14
        static let roomy: CGFloat = 16
        static let grid: CGFloat = 18
        static let section: CGFloat = 20
        static let page: CGFloat = 24
        static let pageHeaderPadding: CGFloat = 32
        static let largeSpacer: CGFloat = 72
    }

    enum Size {
        static let urlBarIcon: CGFloat = 22
        static let iconButton: CGFloat = 28
        static let largeIconButton: CGFloat = 32
        static let floatingButton: CGFloat = 36
        static let urlBarHeight: CGFloat = 34
        static let tabHeight: CGFloat = 34
        static let thumbnail: CGFloat = 52
        static let tabStripHeight: CGFloat = 42
        static let toolbarRowHeight: CGFloat = 48
        static let trafficLightWidth: CGFloat = 78
        static let sidePanelWidth: CGFloat = 260
        static let sidePanelContentWidth: CGFloat = 228
        static let newTabGridMax: CGFloat = 560
        static let internalPageMax: CGFloat = 680
    }

    static let fastAnimation = Animation.easeInOut(duration: 0.16)
    static let springAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let popupAnimation = Animation.spring(response: 0.2, dampingFraction: 0.8)
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
    func motionAwareAnimation<Value: Equatable>(_ animation: Animation?, value: Value) -> some View {
        modifier(MotionAwareAnimationModifier(animation: animation, value: value))
    }

    func motionAwareSymbolReplacement() -> some View {
        modifier(MotionAwareSymbolReplacementModifier())
    }

    func motionAwareSymbolRotation(isActive: Bool) -> some View {
        modifier(MotionAwareSymbolRotationModifier(isActive: isActive))
    }

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

    func navClusterBackground() -> some View {
        modifier(NavClusterBackgroundModifier())
    }
}

private struct MotionAwareAnimationModifier<Value: Equatable>: ViewModifier {
    let animation: Animation?
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

private struct MotionAwareSymbolReplacementModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
    }
}

private struct MotionAwareSymbolRotationModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.symbolEffect(.rotate, options: .repeating, isActive: isActive && !reduceMotion)
    }
}

struct NavClusterBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MacDesign.Spacing.tiny)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(0.035))
            }
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.07), lineWidth: MacDesign.Spacing.hairlineThin)
            }
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
    @State private var isHovering = false
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering, !isHovering {
                    isHovering = true
                    cursor.push()
                } else if !hovering, isHovering {
                    isHovering = false
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
    }
}

struct CappedDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: MacDesign.Spacing.hairline)
            .opacity(0.7)
    }
}

struct CavedDivider: View {
    var body: some View {
        CappedDivider()
    }
}

extension Font {
    static let webHero = Font.system(size: 40, weight: .semibold, design: .rounded)
    static let webInternalPageTitle = Font.system(size: 26, weight: .bold, design: .rounded)
    static let webH1   = Font.system(size: 24, weight: .semibold)
    static let webH2   = Font.system(size: 20, weight: .medium)
    static let webInternalPageIcon = Font.system(size: 22, weight: .semibold)
    static let webMonogram = Font.system(size: 18, weight: .medium, design: .rounded)
    static let webBody = Font.system(size: 14)
    static let webCaption = Font.system(size: 13)
    static let webCaptionBold = Font.system(size: 13, weight: .semibold)
    static let webCaptionMonospaced = Font.system(size: 13).monospaced()
    static let webMicro = Font.system(size: 12.5)
    static let webMicroMedium = Font.system(size: 12.5, weight: .medium)
    static let webSmallRegular = Font.system(size: 11)
    static let webSmallRegularMedium = Font.system(size: 11, weight: .medium)
    static let webSmall = Font.system(size: 10)
    static let webSmallBold = Font.system(size: 10, weight: .bold)
    static let webTinyBold = Font.system(size: 8, weight: .bold)
    static let webBadge = Font.system(size: 7.5, weight: .bold, design: .rounded)
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

    var resolvedHSL: (h: Double, s: Double, l: Double) {
        Color.AppColor.hslComponents(of: self)
    }

    var slightlyDarker: Color {
        let hsl = Color.AppColor.hslComponents(of: self)
        return Color.AppColor.hsl(h: hsl.h, s: hsl.s, l: max(0, hsl.l - 0.12))
    }
}
