//
//  ProtectionSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

struct ProtectionSettingsView: View {
    @EnvironmentObject private var environment: ProfileEnvironment

    var body: some View {
        Form {
            Section("Web Protection") {
                Toggle(isOn: Binding(
                    get: { environment.adBlockService.isEnabled },
                    set: { environment.adBlockService.isEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable ad blocker")
                        Text("Block known advertising and tracking resources while pages load.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

            }
        }
        .settingsForm()
    }
}
