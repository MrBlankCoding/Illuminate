//
//  ShortcutsSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

struct ShortcutsSettingsView: View {

    private struct ShortcutGroup {
        let title: String
        let shortcuts: [(String, String)]
    }

    private let groups: [ShortcutGroup] = [
        ShortcutGroup(title: "Tabs & Windows", shortcuts: [
            ("New Tab",              "⌘T"),
            ("Close Tab",            "⌘W"),
            ("Close All Tabs",       "⌘⇧W"),
            ("Reopen Closed Tab",    "⌘⇧T"),
            ("Next Tab",             "⌘↓"),
            ("Previous Tab",         "⌘↑"),
            ("Switch to Most Recent Tab", "⌃⇥"),
            ("New Window",           "⌘N"),
            ("New Private Window",   "⌘⇧N"),
        ]),
        ShortcutGroup(title: "Tab Groups", shortcuts: [
            ("New Tab Group",                    "⌘⌥G"),
            ("Close Current Group",              "⌘⌥⇧W"),
            ("Move Tab to Left Group",           "⌘⌥←"),
            ("Move Tab to Right Group",          "⌘⌥→"),
        ]),
        ShortcutGroup(title: "Navigation", shortcuts: [
            ("Focus Address Bar",    "⌘L"),
            ("Copy Current URL",     "⌘⇧C"),
            ("Reload Page",          "⌘R"),
            ("Go Back",              "⌘←"),
            ("Go Forward",           "⌘→"),
            ("Toggle Full Screen",   "⌘⇧F"),
        ]),
        ShortcutGroup(title: "History", shortcuts: [
            ("Show All History",     "⌘Y"),
            ("Clear History",        "⌘⇧⌫"),
        ]),
        ShortcutGroup(title: "Page", shortcuts: [
            ("Find in Page",         "⌘F"),
            ("Print Page",           "⌘P"),
            ("Zoom In",              "⌘+"),
            ("Zoom Out",             "⌘−"),
            ("Reset Zoom",           "⌘0"),
            ("Developer Tools",      "⌘⇧I"),
        ]),
        ShortcutGroup(title: "Bookmarks", shortcuts: [
            ("Bookmark Tab", "⌘B"),
        ]),
    ]

    var body: some View {
        Form {
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.shortcuts, id: \.0) { title, shortcut in
                        LabeledContent(title) {
                            Text(shortcut)
                                .font(.caption.monospaced().bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .settingsForm()
    }
}
