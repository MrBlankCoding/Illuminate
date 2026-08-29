//
//  ThemeColorMath.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import AppKit

enum ThemeColorMath {

    static func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let delta = maxV - minV
        let l = (maxV + minV) / 2

        guard delta > 0.000_01 else {
            return (0, 0, l)
        }

        let s = l > 0.5 ? delta / (2 - maxV - minV) : delta / (maxV + minV)

        var h: Double
        if maxV == r {
            h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxV == g {
            h = (b - r) / delta + 2
        } else {
            h = (r - g) / delta + 4
        }
        h /= 6
        if h < 0 { h += 1 }

        return (h, s, l)
    }

    static func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        guard s > 0.000_01 else {
            return (l, l, l)
        }

        func hue2rgb(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        let r = hue2rgb(p, q, h + 1.0 / 3)
        let g = hue2rgb(p, q, h)
        let b = hue2rgb(p, q, h - 1.0 / 3)

        return (r, g, b)
    }

    static func hslToColor(h: Double, s: Double, l: Double) -> Color {
        let rgb = hslToRGB(h: h, s: s, l: l)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    static func hslFromHex(_ hex: String) -> (h: Double, s: Double, l: Double) {
        Color(hex: hex).resolvedHSL
    }

    static func pointToHueSaturation(position: CGPoint) -> (hue: Double, saturation: Double) {
        let x = min(max(position.x, 0), 1)
        let y = min(max(position.y, 0), 1)

        let hue = x
        let distanceFromCenter = abs(y - 0.5) * 2
        let saturation = max(0.15, 1 - distanceFromCenter * 0.6)
        return (hue, saturation)
    }

    static func colorToPoint(hue: Double, saturation: Double) -> CGPoint {
        let x = hue
        let distanceFromCenter = max(0, min(1, (1 - saturation) / 0.6))
        let y = 0.5 + (distanceFromCenter / 2)
        return CGPoint(x: x, y: y)
    }

    static func normalizedHue(_ hue: Double) -> Double {
        var h = hue.truncatingRemainder(dividingBy: 1)
        if h < 0 { h += 1 }
        return h
    }

    static func relatedHues(baseHue: Double, count: Int, algorithm: ThemeAlgorithm) -> [Double] {
        guard count > 0 else { return [] }

        switch algorithm {
        case .floating:
            return Array(repeating: baseHue, count: count)
        }
    }
}

enum ThemeAlgorithm: String, Codable, CaseIterable, Hashable {
    case floating
}

extension Color {
    var resolvedHSL: (h: Double, s: Double, l: Double) {
        let resolved = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return ThemeColorMath.rgbToHSL(r: Double(r), g: Double(g), b: Double(b))
    }
}
