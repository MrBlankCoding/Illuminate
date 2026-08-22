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
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                if let icon = request.context.webExtension.icon(for: CGSize(width: 64, height: 64)) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "puzzlepiece.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        )
                }
                
                Text(request.context.webExtension.displayName ?? "An extension")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Permission Request")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("\(request.context.webExtension.displayName ?? "This extension") is requesting additional permissions:")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let permissions = request.permissions {
                            ForEach(Array(permissions), id: \.self) { perm in
                                HStack(spacing: 8) {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(perm.rawValue)
                                        .font(.subheadline)
                                }
                            }
                        }
                        
                        if let patterns = request.matchPatterns {
                            ForEach(Array(patterns), id: \.description) { pattern in
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Access to \(pattern.description)")
                                        .font(.subheadline)
                                }
                            }
                        }

                        if let urls = request.urls {
                            ForEach(Array(urls), id: \.absoluteString) { url in
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(url.absoluteString)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxHeight: 200)
            }
            
            HStack(spacing: 16) {
                Button("Deny") {
                    request.completion(false)
                    profileEnvironment.extensionManager.activePermissionRequest = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Allow") {
                    request.completion(true)
                    profileEnvironment.extensionManager.activePermissionRequest = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onDisappear {
            profileEnvironment.extensionManager.activePermissionRequest = nil
        }
    }
}
