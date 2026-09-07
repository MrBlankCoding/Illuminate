//
//  SettingsRootView.swift
//  Illuminate
//
//  Root view for Settings window that provides environment objects
//

import SwiftUI
import SwiftData

struct SettingsRootView: View {
    let profileManager: ProfileManager
    let updateManager: UpdateManager
    let modelContainer: ModelContainer
    
    var body: some View {
        NativeSettingsView()
            .environment(profileManager)
            .environment(updateManager)
            .modelContainer(modelContainer)
    }
}
