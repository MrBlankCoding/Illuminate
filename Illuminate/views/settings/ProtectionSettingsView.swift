//
//  ProtectionSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

struct ProtectionSettingsView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsShared.panelSection {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsShared.infoRow(title: "Enable ad blocker") {
                        Toggle("", isOn: Binding(
                            get: { environment.adBlockService.isEnabled },
                            set: { environment.adBlockService.isEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                    }

                    SettingsShared.infoRow(title: "Block cross-site redirects") {
                        Toggle("", isOn: Binding(
                            get: { environment.redirectProtectionService.isEnabled },
                            set: { environment.redirectProtectionService.isEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                    }
                }
            }
        }
    }
}
