//
//  ThemeTextureDial.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import SwiftUI

struct ThemeTextureDial: View {
    @Binding var value: Double

    private let positionCount = 16
    private let dialDiameter: CGFloat = 76
    private let dotDiameter: CGFloat = 5
    private let dotOrbitRadius: CGFloat = 41

    private var frameSide: CGFloat { dialDiameter + dotOrbitRadius * 0.55 }

    var body: some View {
        ZStack {
            ForEach(0..<positionCount, id: \.self) { index in
                dot(at: index)
            }

            Circle()
                .fill(Color(white: 0.08))
                .frame(width: dialDiameter, height: dialDiameter)
                .overlay(
                    Canvas { context, size in
                        ThemeGradientRenderer.drawGrain(context: context, size: size, intensity: 0.6)
                    }
                    .clipShape(Circle())
                )
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .frame(width: frameSide, height: frameSide)
        .contentShape(Circle())
        .gesture(dragGesture)
        .accessibilityElement()
        .accessibilityLabel(Text("Texture"))
        .accessibilityValue(Text("Position \(selectedIndex + 1) of \(positionCount)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func dot(at index: Int) -> some View {
        let angle = angle(for: index)
        let isSelected = selectedIndex == index
        let x = cos(angle) * dotOrbitRadius
        let y = sin(angle) * dotOrbitRadius
        let size = isSelected ? dotDiameter + 2 : dotDiameter

        return Circle()
            .fill(isSelected ? Color.white : Color.white.opacity(0.3))
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    private var selectedIndex: Int {
        let raw = Int((value * Double(positionCount)).rounded())
        return ((raw % positionCount) + positionCount) % positionCount
    }

    private func angle(for index: Int) -> Double {
        2 * .pi * Double(index) / Double(positionCount) - .pi / 2
    }

    private func step(by delta: Int) {
        let next = ((selectedIndex + delta) % positionCount + positionCount) % positionCount
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            value = Double(next) / Double(positionCount)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { drag in
                let center = CGPoint(x: frameSide / 2, y: frameSide / 2)
                let dx = drag.location.x - center.x
                let dy = drag.location.y - center.y

                var angle = atan2(dy, dx) + .pi / 2
                if angle < 0 { angle += 2 * .pi }

                let rawIndex = angle / (2 * .pi) * Double(positionCount)
                let snapped = Int(rawIndex.rounded()) % positionCount
                value = Double(snapped) / Double(positionCount)
            }
    }
}

#Preview {
    ThemeTextureDial(value: .constant(0.0))
        .padding(40)
        .background(Color.black)
}
