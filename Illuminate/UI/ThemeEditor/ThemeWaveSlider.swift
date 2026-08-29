//
//  ThemeWaveSlider.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct ThemeWaveSlider: View {
    @Binding var value: Double

    private let trackHeight: CGFloat = 44
    private let thumbWidth: CGFloat = 30
    private let thumbHeight: CGFloat = 84

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usableWidth = max(width - thumbWidth, 1)
            let thumbX = thumbWidth / 2 + CGFloat(value) * usableWidth

            ZStack {
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: trackHeight)

                WaveShape(amplitude: 7, wavelength: 42)
                    .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbWidth / 2)

                RoundedRectangle(cornerRadius: thumbWidth / 2, style: .continuous)
                    .fill(Color.white)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .position(x: thumbX, y: geo.size.height / 2)
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: value)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { drag in
                        let x = min(max(drag.location.x - thumbWidth / 2, 0), usableWidth)
                        value = Double(x / usableWidth)
                    }
            )
        }
        .frame(height: thumbHeight)
        .accessibilityElement()
        .accessibilityLabel(Text("Opacity"))
        .accessibilityValue(Text("\(Int(value * 100)) percent"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
        }
    }
}

private struct WaveShape: Shape {
    var amplitude: CGFloat
    var wavelength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 else { return path }

        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY))

        var x: CGFloat = rect.minX
        while x <= rect.maxX {
            let relativeX = x - rect.minX
            let y = midY + amplitude * sin((relativeX / wavelength) * 2 * .pi)
            path.addLine(to: CGPoint(x: x, y: y))
            x += 1
        }

        return path
    }
}

#Preview {
    ThemeWaveSlider(value: .constant(0.38))
        .padding(40)
        .background(Color.black)
}
