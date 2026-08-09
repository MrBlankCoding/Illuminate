//
//  ShortcutsSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

struct ShortcutsSettingsView: View {
    private let shortcuts: [(String, String)] = [
        ("New Tab", "⌘T"),
        ("Close Tab", "⌘W"),
        ("Close All Tabs", "⌘⇧W"),
        ("Reopen Closed Tab", "⌘⇧T"),
        ("Bookmark Tab", "⌘B"),
        ("Toggle Bookmark Bar", "⌘⇧B"),
        ("Focus Address Bar", "⌘L"),
        ("Reload Page", "⌘R"),
        ("Find in Page", "⌘F"),
        ("Toggle Full Screen", "⌘⇧F"),
        ("Developer Tools", "⌘⇧I"),
        ("Zoom In", "⌘+"),
        ("Zoom Out", "⌘-"),
        ("Reset Zoom", "⌘0"),
        ("Go Back", "⌘←"),
        ("Go Forward", "⌘→")
    ]

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                ForEach(shortcuts, id: \.0) { title, shortcut in
                    LabeledContent(title) {
                        Text(shortcut)
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .settingsForm()
    }
}
