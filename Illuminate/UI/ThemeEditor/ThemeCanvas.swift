//
//  ThemeCanvas.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct ThemeCanvas: View {
    @Binding var theme: IlluminateTheme
    @Binding var selectedColorID: UUID?
var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                canvasBackground
                
                DotGrid()
                
                ForEach(theme.colors) { point in
                    ThemeColorPointView(
                        point: point,
                        isSelected: point.id == selectedColorID,
                        opacity: theme.opacity,
                        texture: theme.texture
                    )
                    .position(
                        x: point.position.x * size.width,
                        y: point.position.y * size.height
                    )
                    .highPriorityGesture(dragGesture(for: point, in: size))
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedColorID = point.id
                        }
                    }
                }
            }
        }
    }

    private var canvasBackground: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [Color(white: 0.10), Color(white: 0.05)],
                    center: .center,
                    startRadius: 10,
                    endRadius: 420
                )
            )
    }

    private func dragGesture(for point: ThemeColorPoint, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard let index = theme.colors.firstIndex(where: { $0.id == point.id }) else { return }

                let x = min(max(value.location.x / size.width, 0), 1)
                let y = min(max(value.location.y / size.height, 0), 1)
                let newPosition = CGPoint(x: x, y: y)

                theme.colors[index].position = newPosition

                let (hue, saturation) = ThemeColorMath.pointToHueSaturation(position: newPosition)
                theme.colors[index].hue = hue
                theme.colors[index].saturation = saturation

                if selectedColorID != point.id {
                    selectedColorID = point.id
                }
            }
    }
}

private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            ThemeGradientRenderer.drawDotGrid(
                context: context,
                size: size,
                spacing: 7,
                dotRadius: 0.6,
                color: Color.white.opacity(0.16)
            )
        }
        .allowsHitTesting(false)
    }
}

private struct ThemeColorPointView: View {
    let point: ThemeColorPoint
    let isSelected: Bool
    let opacity: Double
    let texture: Double

    private let diameter: CGFloat = 46
    private let innerRatio: CGFloat = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.22), radius: isSelected ? 7 : 3, y: 2)

            Circle()
                .fill(point.color.opacity(max(0.02, opacity)))
                .frame(width: diameter * innerRatio, height: diameter * innerRatio)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .blur(radius: 2)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    Canvas { context, size in
                        ThemeGradientRenderer.drawGrain(context: context, size: size, intensity: texture * 3.0)
                    }
                    .clipShape(Circle())
                    .frame(width: diameter * innerRatio, height: diameter * innerRatio)
                )
        }
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .contentShape(Circle().inset(by: -8)) // slightly larger hit target than the visible ring
    }
}

#Preview {
    ThemeCanvas(theme: .constant(.default), selectedColorID: .constant(nil))
        .frame(width: 340, height: 340)
        .padding(20)
        .background(Color.black)
}
