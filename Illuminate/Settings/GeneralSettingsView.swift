//
//  GeneralSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $hapticFeedbackEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptic Feedback")
                            .font(.body)
                        Text("Provides subtle tactile feedback for selected browser interactions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.general.hapticFeedbackToggle")
            } header: {
                Text("General")
            } footer: {
                Text("Haptics use the trackpad and are silent on devices without Force Touch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .settingsForm()
    }
}
