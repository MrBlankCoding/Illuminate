//
//  ThemeModel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

enum ThemeScheme: String, Codable, CaseIterable, Hashable {
    case automatic
    case light
    case dark

    var title: String {
        switch self {
        case .automatic: return "System"
        case .light:     return "Light"
        case .dark:      return "Dark"
        }
    }

    func toUIStyle() -> TabManager.UIStyle {
        switch self {
        case .automatic: return .system
        case .light:     return .light
        case .dark:      return .dark
        }
    }

    static func fromUIStyle(_ style: TabManager.UIStyle) -> ThemeScheme {
        switch style {
        case .system: return .automatic
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct ThemeColorPoint: Identifiable, Codable, Equatable {
    let id: UUID
    var position: CGPoint
    var hue: Double        // 0...1
    var saturation: Double // 0...1
    var lightness: Double  // 0...1

    init(
        id: UUID = UUID(),
        position: CGPoint,
        hue: Double,
        saturation: Double,
        lightness: Double
    ) {
        self.id = id
        self.position = position
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }

    /// Convenience accessor. Views should read this rather than re-deriving
    /// color from HSL themselves.
    var color: Color {
        ThemeColorMath.hslToColor(h: hue, s: saturation, l: lightness)
    }
}

/// The full, persistable state of an Illuminate theme.
struct IlluminateTheme: Codable, Equatable {
    var colors: [ThemeColorPoint]
    var opacity: Double   // driven by the wave slider, 0...1
    var texture: Double   // driven by the texture dial, 0...1 (16 discrete steps)
    var rotation: Double
    var colorScheme: ThemeScheme
    var algorithm: ThemeAlgorithm

    /// A reasonable starting theme: a single neutral grey point.
    static var `default`: IlluminateTheme {
        let grey = Color(white: 0.5).resolvedHSL

        return IlluminateTheme(
            colors: [
                ThemeColorPoint(
                    position: CGPoint(x: 0.5, y: 0.5),
                    hue: grey.h, saturation: grey.s, lightness: grey.l
                )
            ],
            opacity: 0.38,
            texture: 1.0 / 16.0,
            rotation: 0,
            colorScheme: .automatic,
            algorithm: .floating
        )
    }
}
