//
//  ThemeGradientRenderer.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

enum ThemeGradientRenderer {
    static func drawDotGrid(
        context: GraphicsContext,
        size: CGSize,
        spacing: CGFloat = 7,
        dotRadius: CGFloat = 0.6,
        color: Color
    ) {
        guard spacing > 0 else { return }

        let style = GraphicsContext.Shading.color(color)
        var x: CGFloat = spacing / 2
        while x < size.width {
            var y: CGFloat = spacing / 2
            while y < size.height {
                let rect = CGRect(
                    x: x - dotRadius,
                    y: y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                context.fill(Path(ellipseIn: rect), with: style)
                y += spacing
            }
            x += spacing
        }
    }
    // TODO
    // grain is too strong
    static func drawGrain(
        context: GraphicsContext,
        size: CGSize,
        intensity: Double,
        seed: UInt64 = 42
    ) {
        var generator = SeededGenerator(seed: seed)
        let dotCount = max(0, Int(size.width * size.height * 2.5)) // Increase density

        for _ in 0..<dotCount {
            let x = CGFloat.random(in: 0...max(size.width, 0.001), using: &generator)
            let y = CGFloat.random(in: 0...max(size.height, 0.001), using: &generator)
            
            // Randomly choose between light and dark grain
            let isLight = Bool.random(using: &generator)
            let alpha = Double.random(in: 0.05...0.2, using: &generator) * intensity
            let radius = CGFloat.random(in: 0.3...0.6, using: &generator)
            
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            let color = isLight ? Color.white.opacity(alpha) : Color.black.opacity(alpha)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
