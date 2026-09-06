//
//  GeneralSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @AppStorage(TabManager.keepInactiveTabsLoadedKey) private var keepInactiveTabsLoaded = true
    @AppStorage(TabManager.autoRestorePreviousTabsKey) private var autoStartPreviousTabs = true
    @AppStorage(WebKitManager.javascriptEnabledKey) private var javascriptEnabled = true
    @AppStorage(BrowserAppearanceSettings.compactModeKey) private var compactMode = false
    @AppStorage(BrowserAppearanceSettings.animationsEnabledKey) private var animationsEnabled = true
    @AppStorage(Tab.autoPictureInPictureKey) private var autoPictureInPicture = false
    @AppStorage(AppDelegate.warnBeforeQuittingKey) private var warnBeforeQuitting = true

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

                Toggle(isOn: $keepInactiveTabsLoaded) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep tabs loaded")
                            .font(.body)
                        Text("Keep background tabs resident in memory so switching is instant. This uses more RAM.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.general.keepInactiveTabsLoadedToggle")
            } header: {
                Text("General")
            } footer: {
                Text("Toggle this based on your device performance and memory availability.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Auto-start with previous tabs", isOn: $autoStartPreviousTabs)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.general.autoStartPreviousTabsToggle")

                Toggle("JavaScript", isOn: $javascriptEnabled)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.general.javascriptToggle")
            } header: {
                Text("Performance")
            }

            Section {
                Toggle(isOn: $autoPictureInPicture) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Picture-in-Picture")
                            .font(.body)
                        Text("Automatically enter Picture-in-Picture when a video is detected on a page.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.general.autoPictureInPictureToggle")
            } header: {
                Text("Media")
            }

            Section {
                Toggle(isOn: $compactMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compact experience")
                            .font(.body)
                        Text("Tightens spacing and control sizes for denser browsing layouts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.general.compactModeToggle")

                Toggle("Animations", isOn: $animationsEnabled)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.general.animationsToggle")
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Warn before quitting", isOn: $warnBeforeQuitting)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.general.warnBeforeQuittingToggle")
            } header: {
                Text("Safety")
            }
        }
        .settingsForm()
    }
}