//
//  NativeSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

struct NativeSettingsView: View {
    @FocusedValue(\.activeEnvironment) private var activeEnvironment
    private var tabManager: TabManager {
        activeEnvironment?.tabManager ?? TabManager()
    }

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
        .frame(minWidth: 520, minHeight: 440)
        .environmentObject(tabManager)
    }
}
