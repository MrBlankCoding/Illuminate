//
//  SettingsShared.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

enum SettingsTab: Int, CaseIterable, Identifiable {
    case appearance
    case shortcuts
    case passwords
    case cookies
    case downloads
    case additional

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .shortcuts:
            return "Shortcuts"
        case .passwords:
            return "Passwords"
        case .cookies:
            return "Cookies"
        case .downloads:
            return "Downloads"
        case .additional:
            return "Protection"
        }
    }

    var icon: String {
        switch self {
        case .appearance:
            return "paintpalette.fill"
        case .shortcuts:
            return "command"
        case .passwords:
            return "key.fill"
        case .cookies:
            return "circle.hexagongrid.fill"
        case .downloads:
            return "arrow.down.circle.fill"
        case .additional:
            return "shield.lefthalf.filled"
        }
    }
}

struct SettingsShared {
    @ViewBuilder
    static func panelSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground(cornerRadius: 26))
    }

    static func panelBackground(cornerRadius: CGFloat) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }

    static func metricsPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .kerning(1.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(MetricsPillModifier())
    }

    static func infoRow(title: String, tint: Color? = nil, trailing: @escaping () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint ?? Color.textPrimary)

            Spacer()

            trailing()
        }
    }

    static func actionCapsule(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .modifier(ActionCapsuleModifier(tint: tint))
    }

    static func protectionBadge(icon: String, title: String, tabManager: TabManager) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tabManager.windowThemeColor)
                .frame(width: 36, height: 36)
                .background(tabManager.windowThemeColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .modifier(ProtectionBadgeModifier(tint: tabManager.windowThemeColor))
    }

    static func glassBox(cornerRadius: CGFloat = 16, tint: Color? = nil) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                let effect: Glass = tint.map {
                    .regular.tint($0.opacity(0.12)).interactive()
                } ?? .regular.interactive()
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .glassEffect(effect, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint?.opacity(0.08) ?? Color.primary.opacity(0.05))
            }
        }
    }
}

private struct MetricsPillModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            content
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct ActionCapsuleModifier: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(0.14)).interactive(), in: Capsule())
        } else {
            content
                .background(tint.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

private struct ProtectionBadgeModifier: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(0.10)),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
        } else {
            content
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

extension TabManager.UIStyle {
    var title: String {
        switch self {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        case .system:
            return "System"
        }
    }
}
