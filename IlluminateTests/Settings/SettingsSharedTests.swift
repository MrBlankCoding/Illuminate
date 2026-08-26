//
//  SettingsSharedTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI
import Testing
@testable import Illuminate

struct SettingsSharedTests {
    @Test func settingsTabsAndStylesExposeAllLabels() {
        #expect(SettingsTab.allCases.count == 3)
        #expect(SettingsTab.appearance.title == "Appearance")
        #expect(SettingsTab.shortcuts.title == "Shortcuts")
        #expect(SettingsTab.downloads.title == "Downloads")
        #expect(SettingsTab.appearance.icon == "paintpalette")
        #expect(SettingsTab.shortcuts.icon == "command")
        #expect(SettingsTab.downloads.icon == "arrow.down.circle")
        #expect(TabManager.UIStyle.dark.title == "Dark")
        #expect(TabManager.UIStyle.light.title == "Light")
        #expect(TabManager.UIStyle.system.title == "System")
    }

    @Test func sharedSettingsViewsCanBeConstructed() {
        _ = SettingsShared.form(Text("content"))
        _ = SettingsShared.panelSection { Text("section") }
        _ = SettingsShared.infoRow(title: "Info", tint: .blue) { Text("value") }
        _ = SettingsShared.compactAction(icon: "star", title: "Action", tint: .blue)
        _ = SettingsShared.actionCapsule(icon: "star", title: "Action", tint: .blue)
        _ = SettingsShared.glassBox(tint: .blue)
    }
}
