//
//  NativeSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 2026-08-09.
//

import SwiftUI

struct NativeSettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

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
    }
}
