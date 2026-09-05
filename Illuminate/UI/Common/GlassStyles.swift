//
//  GlassStyles.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/2/26.
//

import SwiftUI

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
                    .stroke(Color.primary.opacity(strokeOpacity), lineWidth: MacDesign.Spacing.hairlineThin)
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
                    .stroke(Color.primary.opacity(0.10), lineWidth: MacDesign.Spacing.hairlineThin)
            }
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

struct MacControlBackgroundModifier: ViewModifier {
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
                    .stroke(stroke, lineWidth: MacDesign.Spacing.hairlineThin)
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

struct ToolbarIconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
    func browserPanel(cornerRadius: CGFloat = MacDesign.Radius.control) -> some View {
        self.modifier(MacMaterialModifier(cornerRadius: cornerRadius, style: .regular, strokeOpacity: 0.09))
    }

    @ViewBuilder
    func insetPanel(cornerRadius: CGFloat = 8) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: MacDesign.Spacing.hairlineThin)
            }
    }

    @ViewBuilder
    func accentGlassPanel(accent: Color, cornerRadius: CGFloat = MacDesign.Radius.control) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accent.opacity(0.13))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: MacDesign.Spacing.hairlineThin)
            }
    }

    @ViewBuilder
    func floatingGlassPanel(cornerRadius: CGFloat = MacDesign.Radius.control) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: MacDesign.Spacing.hairlineThin)
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
