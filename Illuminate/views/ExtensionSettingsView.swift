//
//  ExtensionSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/21/26.
//

import SwiftUI
import WebKit

struct ExtensionSettingsView: View {
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @State private var selectedExtension: IdentifiableContext?
    @State private var showingGallery = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(profileEnvironment.extensionManager.installedExtensions, id: \.self) { context in
                        HStack {
                            if let icon = context.webExtension.icon(for: CGSize(width: 32, height: 32)) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: "puzzlepiece.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(context.webExtension.displayName ?? "Unknown Extension")
                                    .font(.headline)
                                Text("Version \(context.webExtension.version ?? "1.0")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { profileEnvironment.extensionManager.isEnabled(context) },
                                set: { profileEnvironment.extensionManager.setEnabled(context, enabled: $0) }
                            ))
                            .toggleStyle(.switch)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedExtension = IdentifiableContext(context: context)
                        }
                    }
                } header: {
                    Text("Installed Extensions")
                } footer: {
                    if profileEnvironment.extensionManager.installedExtensions.isEmpty {
                        Text("No extensions installed for this profile.")
                    }
                }
                
                Section {
                    Button {
                        showingGallery = true
                    } label: {
                        Label("Browse Extension Gallery", systemImage: "cart.fill")
                    }
                }
            }
            .navigationTitle("Extensions")
            .sheet(item: $selectedExtension) { wrapper in
                ExtensionDetailView(context: wrapper.context)
                    .environmentObject(profileEnvironment)
            }
            .sheet(isPresented: $showingGallery) {
                ExtensionGalleryView()
                    .environmentObject(profileEnvironment)
            }
        }
    }
}

struct IdentifiableContext: Identifiable {
    let context: WKWebExtensionContext
    var id: ObjectIdentifier { ObjectIdentifier(context) }
}

struct ExtensionDetailView: View {
    let context: WKWebExtensionContext
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                if let icon = context.webExtension.icon(for: CGSize(width: 64, height: 64)) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }
                
                VStack(alignment: .leading) {
                    Text(context.webExtension.displayName ?? "Unknown Extension")
                        .font(.title)
                    Text(context.webExtension.version ?? "")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Description")
                    .font(.headline)
                Text(context.webExtension.displayDescription ?? "No description available.")
            }
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Permissions")
                    .font(.headline)
                
                let grantedPermissions = Set(context.grantedPermissions.keys)
                if !grantedPermissions.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Granted Permissions:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(Array(grantedPermissions), id: \.self) { permission in
                            Text("• \(permission.rawValue)")
                        }
                    }
                }
                
                let requestedOnly = context.webExtension.requestedPermissions.subtracting(grantedPermissions)
                if !requestedOnly.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Requested (Not Granted):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(Array(requestedOnly), id: \.self) { permission in
                            Text("• \(permission.rawValue)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                let grantedPatterns = Set(context.grantedPermissionMatchPatterns.keys)
                if !grantedPatterns.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Site Access:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(Array(grantedPatterns), id: \.description) { pattern in
                            Text("• \(pattern.description)")
                        }
                    }
                }
                
                if grantedPermissions.isEmpty && grantedPatterns.isEmpty && requestedOnly.isEmpty {
                    Text("No special permissions requested.")
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack {
                Button("Options") {
                    profileEnvironment.extensionManager.webExtensionController(
                        profileEnvironment.extensionManager.controller,
                        openOptionsPageFor: context
                    ) { _ in }
                    dismiss()
                }
                .disabled(!hasOptionsPage)
                
                Spacer()
                
                Button("Uninstall", role: .destructive) {
                    profileEnvironment.extensionManager.uninstallExtension(context)
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    private var hasOptionsPage: Bool {
        let manifest = context.webExtension.manifest
        return manifest["options_page"] != nil || (manifest["options_ui"] as? [String: Any])?["page"] != nil
    }
}
