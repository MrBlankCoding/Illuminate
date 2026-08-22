//
//  PermissionRequestView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/21/26.
//

import SwiftUI
import WebKit

struct PermissionRequestView: View {
    let request: ExtensionManager.PermissionRequest
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    
    var body: some View {
        VStack(spacing: 20) {
            if let icon = request.context.webExtension.icon(for: CGSize(width: 48, height: 48)) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
            }
            
            Text("Permission Request")
                .font(.headline)
            
            Text("\(request.context.webExtension.displayName ?? "An extension") is requesting additional permissions:")
                .multilineTextAlignment(.center)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let permissions = request.permissions {
                        ForEach(Array(permissions), id: \.self) { perm in
                            Text("• \(perm.rawValue)")
                        }
                    }
                    
                    if let patterns = request.matchPatterns {
                        ForEach(Array(patterns), id: \.description) { pattern in
                            Text("• Access to \(pattern.description)")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(maxHeight: 200)
            
            HStack(spacing: 15) {
                Button("Deny") {
                    request.completion(false)
                    profileEnvironment.extensionManager.activePermissionRequest = nil
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Allow") {
                    request.completion(true)
                    profileEnvironment.extensionManager.activePermissionRequest = nil
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding()
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
