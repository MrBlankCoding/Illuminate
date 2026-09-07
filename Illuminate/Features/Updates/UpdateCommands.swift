//
//  UpdateCommands.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/25/26.
//

import SwiftUI

struct UpdateCommands: Commands {
    var updateManager: UpdateManager
    
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                updateManager.checkForUpdates()
            }
            .disabled(!updateManager.canCheckForUpdates)
            .keyboardShortcut("u", modifiers: [.command])
            
            Divider()
        }
    }
}
