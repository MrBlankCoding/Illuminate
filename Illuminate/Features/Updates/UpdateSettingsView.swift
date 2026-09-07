//
//  UpdateSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/25/26.
//

import SwiftUI

struct UpdateSettingsView: View {
    @Environment(UpdateManager.self) private var updateManager
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("App Updates")
                                .font(.headline)
                            
                            if let lastCheck = updateManager.lastUpdateCheckDate {
                                Text("Last checked: \(lastCheck, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Never checked for updates")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Check Now") {
                            updateManager.checkForUpdates()
                        }
                        .disabled(!updateManager.canCheckForUpdates)
                    }
                    
                    Divider()
                    
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updateManager.automaticallyChecksForUpdates },
                        set: { updateManager.automaticallyChecksForUpdates = $0 }
                    ))
                    .help("Check for updates in the background every 24 hours")
                    
                    Toggle("Automatically download updates", isOn: Binding(
                        get: { updateManager.automaticallyDownloadsUpdates },
                        set: { updateManager.automaticallyDownloadsUpdates = $0 }
                    ))
                    .help("Download updates automatically when available")
                    .disabled(!updateManager.automaticallyChecksForUpdates)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Update Settings")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 300)
    }
}

#Preview {
    UpdateSettingsView()
        .environment(UpdateManager())
}
