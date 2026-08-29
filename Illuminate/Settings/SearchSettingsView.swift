//
//  SearchSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/29/26.
//

import SwiftUI

struct SearchSettingsView: View {
    @AppStorage("defaultSearchEngine") private var defaultSearchEngine: SearchEngine = .google

    var body: some View {
        Form {
            Section {
                Picker("Default Search Engine", selection: $defaultSearchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.name).tag(engine)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.search.enginePicker")
            } header: {
                Text("Search")
            }
        }
        .settingsForm()
    }
}
