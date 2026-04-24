//
//  ShortcutsSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

struct ShortcutsSettingsView: View {
    @EnvironmentObject private var tabManager: TabManager

    var body: some View {
        let shortcuts: [(String, String)] = [
            ("New Tab", "⌘ T"),
            ("Close Tab", "⌘ W"),
            ("Close All Tabs", "⌘ ⇧ W"),
            ("Reopen Closed Tab", "⌘ ⇧ T"),
            ("Bookmark Tab", "⌘ B"),
            ("Focus URL Bar", "⌘ L"),
            ("Refresh Page", "⌘ R"),
            ("Find in Page", "⌘ F"),
            ("Toggle Full Screen", "⌘ ⇧ F"),
            ("Toggle Sidebar", "⌘ S"),
            ("Zoom In", "⌘ +"),
            ("Zoom Out", "⌘ −"),
            ("Reset Zoom", "⌘ 0"),
            ("Go Back", "⌘ ←"),
            ("Go Forward", "⌘ →"),
            ("Developer Tools", "⌘ ⇧ I")
        ]

        return SettingsShared.panelSection {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {
                ForEach(shortcuts, id: \.0) { shortcut in
                    HStack {
                        HStack {
                            Text(shortcut.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(shortcut.1)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(tabManager.windowThemeColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(tabManager.windowThemeColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }
}
