//
//  ColorUtilities.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/2/26.
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

    func hexString() -> String { toHex() ?? "FFFFFF" }

    func blended(with color: Color, fraction: CGFloat) -> Color {
        let lhs = NSColor(self).usingColorSpace(.deviceRGB) ?? .white
        let rhs = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        return Color(lhs.blended(withFraction: fraction, of: rhs) ?? lhs)
    }

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
    }

    var slightlyDarker: Color {
        let hsl = Color.AppColor.hslComponents(of: self)
        return Color.AppColor.hsl(h: hsl.h, s: hsl.s, l: max(0, hsl.l - 0.12))
    }
}
