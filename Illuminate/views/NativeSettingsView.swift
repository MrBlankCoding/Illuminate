//
//  NativeSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
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
        .frame(minWidth: 520, minHeight: 400)
        .environmentObject(activeEnvironment?.tabManager ?? TabManager())
    }
}
