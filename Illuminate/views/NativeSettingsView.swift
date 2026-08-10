//
//  NativeSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 2026-08-09.
//

import SwiftUI

struct NativeSettingsView: View {
    @FocusedValue(\.activeEnvironment) private var activeEnvironment

    var body: some View {
        TabView {
            DownloadsSettingsView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }
        }
        .frame(minWidth: 500, minHeight: 360)
        .environmentObject(activeEnvironment?.tabManager ?? TabManager())
    }
}
