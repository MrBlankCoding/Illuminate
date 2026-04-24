//
//  UiTheme.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/10/26.
//

import SwiftUI
import AppKit

private let colorShaderLibrary = ShaderLibrary.bundle(Bundle.main)

extension Color {
    // Base surfaces
    static let bgBase = Color(nsColor: .windowBackgroundColor)
    static let bgSurface = Color.primary.opacity(0.04)
    static let bgElevated = Color.primary.opacity(0.06)

    // Text hierarchy
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary.opacity(0.8)

    // Accent
    static let accentBeam = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.15)

    // Borders
    static let borderGlass = Color.primary.opacity(0.08)

    // Panels
    static let sidebarPanel = Color.primary.opacity(0.02)
}

struct BrowserTheme {
    let accent: Color
    let colorScheme: ColorScheme

    private var isDark: Bool {
        colorScheme == .dark
    }

    var shellBase: Color {
        isDark ? Color(hex: "101216") : Color(hex: "F8F9FB")
    }

    var shellSecondary: Color {
        isDark ? Color(hex: "15181E") : Color(hex: "F3F5F9")
    }

    func shellGradientShader(size: CGSize) -> Shader {
        Shader(function: colorShaderLibrary.shellGradientShader, arguments: [
            .float2(Float(size.width), Float(size.height)),
            .color(shellBase),
            .color(shellSecondary),
            .float(0.05) // grainIntensity
        ])
    }

    var shellGradient: LinearGradient {
        LinearGradient(
            colors: [shellBase, shellSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var ambientGlowPrimary: Color {
        accent.opacity(isDark ? 0.05 : 0.03)
    }

    func ambientGlowShader(size: CGSize) -> Shader {
        Shader(function: colorShaderLibrary.ambientGlowShader, arguments: [
            .float2(Float(size.width), Float(size.height)),
            .color(ambientGlowPrimary),
            .float(0.8) // radiusScale
        ])
    }

    var chromeMaterial: Material {
        isDark ? .ultraThinMaterial : .regularMaterial
    }

    var chromeFill: Color {
        isDark ? Color.black.opacity(0.15) : Color.white.opacity(0.4)
    }

    var chromeStroke: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
    }

    func chromeShader(size: CGSize) -> Shader {
        Shader(function: colorShaderLibrary.chromeShader, arguments: [
            .float2(Float(size.width), Float(size.height)),
            .color(chromeFill),
            .color(accent.opacity(0.1)),
            .float(0.5) // strokeWidth
        ])
    }

    func glassShader(size: CGSize, cornerRadius: CGFloat) -> Shader {
        Shader(function: colorShaderLibrary.glassShader, arguments: [
            .float2(Float(size.width), Float(size.height)),
            .color(accent.opacity(0.05)),
            .float(1.0), // blurIntensity
            .float(Float(cornerRadius))
        ])
    }

    func noiseShader(size: CGSize, time: Double = 0.0, intensity: Double = 0.03) -> Shader {
        Shader(function: colorShaderLibrary.noiseShader, arguments: [
            .float2(Float(size.width), Float(size.height)),
            .float(Float(intensity)),
            .float(Float(time))
        ])
    }

    var chromeInnerGlow: Color {
        Color.clear
    }

    var sidebarTint: Color {
        isDark ? Color.black.opacity(0.1) : Color.white.opacity(0.3)
    }

    var sidebarEdgeTint: Color {
        Color.clear
    }

    var panelFill: Color {
        isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.5)
    }

    var panelRaised: Color {
        isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.8)
    }

    var panelHover: Color {
        accent.opacity(isDark ? 0.1 : 0.08)
    }

    var panelActive: Color {
        accent.opacity(isDark ? 0.15 : 0.12)
    }

    var panelGrouped: Color {
        Color.primary.opacity(0.03)
    }

    var textOnAccent: Color {
        isDark ? .white : .black
    }

    var urlBarTop: Color {
        isDark ? Color.black.opacity(0.2) : Color.white.opacity(0.5)
    }

    var urlBarBottom: Color {
        isDark ? Color.black.opacity(0.25) : Color.white.opacity(0.4)
    }

    var urlBarStroke: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var buttonHoverFill: Color {
        Color.primary.opacity(0.06)
    }

    var buttonPressedFill: Color {
        Color.primary.opacity(0.1)
    }

    var faviconPlateFill: Color {
        isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    var selectionIndicator: Color {
        accent
    }

    var statusFill: Color {
        isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.02)
    }
}


extension Color {

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64

        switch hex.count {
        case 3:
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)

        case 6:
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)

        case 8:
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)

        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        let nsColor = NSColor(self)

        guard let components = nsColor.cgColor.components else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : 1.0

        if a < 1 {
            return String(
                format: "%02lX%02lX%02lX%02lX",
                lroundf(r * 255),
                lroundf(g * 255),
                lroundf(b * 255),
                lroundf(a * 255)
            )
        }

        return String(
            format: "%02lX%02lX%02lX",
            lroundf(r * 255),
            lroundf(g * 255),
            lroundf(b * 255)
        )
    }

    func blended(with color: Color, fraction: CGFloat) -> Color {
        let lhs = NSColor(self).usingColorSpace(.deviceRGB) ?? .white
        let rhs = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        return Color(lhs.blended(withFraction: fraction, of: rhs) ?? lhs)
    }
}

struct GlassModifier: ViewModifier {

    var cornerRadius: CGFloat = 8
    var material: Material = .regularMaterial

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.borderGlass, lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 4,
                y: 2
            )
    }
}

extension Font {

    static let webH1 = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let webH2 = Font.system(size: 20, weight: .medium, design: .rounded)
    static let webBody = Font.system(size: 14)
    static let webMicro = Font.system(size: 12)
}

struct GlassButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {

        configuration.label
            .font(.webBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.regularMaterial)
            )

            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.borderGlass, lineWidth: 0.5)
            )

            .scaleEffect(configuration.isPressed ? 0.98 : 1)

            .animation(
                .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}

struct FocusRingModifier: ViewModifier {

    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isActive ? Color.accentBeam.opacity(0.6) : Color.clear,
                        lineWidth: 3
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

struct CavedDivider: View {

    var body: some View {

        Rectangle()
            .fill(Color.borderGlass)
            .frame(height: 1)
            .opacity(0.4)
            .padding(.vertical, 2)
    }
}

extension View {

    func glassBackground() -> some View {
        self.modifier(GlassModifier())
    }

    func focusRing(_ active: Bool) -> some View {
        self.modifier(FocusRingModifier(isActive: active))
    }

    func hoverCursor(_ cursor: NSCursor) -> some View {
        self.modifier(HoverCursorModifier(cursor: cursor))
    }

    func browserPanel(theme: BrowserTheme, cornerRadius: CGFloat = 10) -> some View {
        self.background(
            Rectangle()
                .visualEffect { [theme] content, proxy in
                    content
                        .colorEffect(theme.chromeShader(size: proxy.size))
                        .colorEffect(theme.noiseShader(size: proxy.size))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .background(theme.chromeMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(theme.chromeStroke, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(theme.colorScheme == .dark ? 0.1 : 0.05), radius: 8, y: 4)
        )
    }

    func ambientGlow(theme: BrowserTheme) -> some View {
        self.visualEffect { [theme] content, proxy in
            content.colorEffect(theme.ambientGlowShader(size: proxy.size))
        }
    }

    func panelBackground(theme: BrowserTheme, cornerRadius: CGFloat = 10) -> some View {
        self.background(
            Rectangle()
                .visualEffect { [theme] content, proxy in
                    content
                        .colorEffect(theme.chromeShader(size: proxy.size))
                        .colorEffect(theme.noiseShader(size: proxy.size))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
    }

    func glassPanel(theme: BrowserTheme, cornerRadius: CGFloat = 10) -> some View {
        self.background(
            Rectangle()
                .visualEffect { [theme] content, proxy in
                    content
                        .colorEffect(theme.glassShader(size: proxy.size, cornerRadius: cornerRadius))
                }
        )
    }

    func noiseEffect(theme: BrowserTheme, opacity: Double = 0.03) -> some View {
        self.visualEffect { [theme] content, proxy in
            content
                .colorEffect(theme.noiseShader(size: proxy.size, intensity: opacity))
        }
    }
}

private struct HoverCursorModifier: ViewModifier {
    let cursor: NSCursor

    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension AngularGradient {
    static var colorfulAngularGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(hue: 0/360, saturation: 1, brightness: 1),
                Color(hue: 60/360, saturation: 1, brightness: 1),
                Color(hue: 120/360, saturation: 1, brightness: 1),
                Color(hue: 180/360, saturation: 1, brightness: 1),
                Color(hue: 240/360, saturation: 1, brightness: 1),
                Color(hue: 300/360, saturation: 1, brightness: 1),
                Color(hue: 360/360, saturation: 1, brightness: 1)
            ]),
            center: .center
        )
    }
}

extension Animation {
    static var browserDefault: Animation {
        .spring(response: 0.3, dampingFraction: 0.8)
    }
}

extension Color {
    func hexString() -> String {
        return toHex() ?? "#FFFFFF"
    }
}
