//
//  ShortcutsSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import KeyboardShortcuts
import SwiftUI

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            ForEach(ShortcutGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        KeyboardShortcuts.Recorder(item.label, name: item.name)
                    }
                }
            }

            Section {
                Button("Reset All to Defaults") {
                    for group in ShortcutGroup.allCases {
                        for item in group.items {
                            if let initial = item.name.initialShortcut {
                                item.name.shortcut = initial
                            }
                        }
                    }
                }
            }
        }
        .settingsForm()
    }
}
