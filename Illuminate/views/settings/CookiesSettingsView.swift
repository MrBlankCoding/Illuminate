//
//  CookiesSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/20/26.
//

import SwiftUI

struct CookiesSettingsView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsShared.panelSection {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsShared.infoRow(title: "Enable cookies") {
                        Toggle("", isOn: Binding(
                            get: { environment.webKitManager.cookiesEnabled },
                            set: { environment.webKitManager.cookiesEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(GlassToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                    }

                    Divider().opacity(0.22)

                    Button(role: .destructive) {
                        CookieViewModel().clearAllCookies(with: environment.webKitManager)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                            Text("Clear all cookies and website data")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(14)
                        .background(SettingsShared.glassBox(cornerRadius: 18, tint: .red))
                    }
                    .buttonStyle(.plain)
                    .hoverCursor(.pointingHand)
                }
            }
        }
    }
}
