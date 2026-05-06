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
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
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
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
            if let tint {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.12))
            }
        }
    }
}

private struct MetricsPillModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ActionCapsuleModifier: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background {
                Capsule().fill(.regularMaterial)
                Capsule().fill(tint.opacity(0.14))
            }
    }
}

private struct ProtectionBadgeModifier: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tint.opacity(0.10))
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
