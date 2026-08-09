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
    case downloads

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .shortcuts:
            return "Shortcuts"
        case .downloads:
            return "Downloads"
        }
    }

    var icon: String {
        switch self {
        case .appearance:
            return "paintpalette"
        case .shortcuts:
            return "command"
        case .downloads:
            return "arrow.down.circle"
        }
    }
}

enum SettingsShared {
    static func form(_ content: some View) -> some View {
        content
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, MacDesign.Spacing.control, for: .scrollContent)
            .contentMargins(.horizontal, MacDesign.Spacing.roomy, for: .scrollContent)
    }

    @ViewBuilder
    static func panelSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MacDesign.Spacing.roomy) {
            content()
        }
        .padding(MacDesign.Spacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .browserPanel(cornerRadius: MacDesign.Radius.panel)
    }

    static func infoRow(title: String, tint: Color? = nil, trailing: @escaping () -> some View) -> some View {
        HStack(alignment: .center, spacing: MacDesign.Spacing.regular) {
            Text(title)
                .font(.body)
                .foregroundStyle(tint ?? Color.textPrimary)

            Spacer()

            trailing()
        }
    }

    static func compactAction(icon: String, title: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundStyle(tint)
    }

    static func actionCapsule(icon: String, title: String, tint: Color) -> some View {
        compactAction(icon: icon, title: title, tint: tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }

    static func glassBox(cornerRadius: CGFloat = MacDesign.Radius.large, tint: Color? = nil) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)

            if let tint {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.10))
            }
        }
    }
}

extension View {
    func settingsForm() -> some View {
        SettingsShared.form(self)
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
