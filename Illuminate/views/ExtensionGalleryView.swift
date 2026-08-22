//
//  ExtensionGalleryView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/21/26.
//

import SwiftUI
import WebKit

struct ExtensionGalleryItem: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let iconURL: String
    let downloadURL: String
    let version: String
}

struct ExtensionGalleryView: View {
    @State private var extensions: [ExtensionGalleryItem] = []
    @State private var isLoading = true
    @EnvironmentObject var profileEnvironment: ProfileEnvironment

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading Extension Gallery...")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                        ForEach(extensions) { item in
                            ExtensionGalleryCard(item: item)
                                .environmentObject(profileEnvironment)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Extension Gallery")
        .onAppear(perform: loadCatalog)
    }

    private func loadCatalog() {
        // Mocking a JSON catalog load
        let mockData = """
        [
            {
                "id": "com.illuminate.adblock",
                "name": "uBlock Lite",
                "description": "A lightweight content blocker for the modern web.",
                "iconURL": "https://example.com/icon1.png",
                "downloadURL": "https://example.com/ublock.appex",
                "version": "1.0.0"
            },
            {
                "id": "com.illuminate.darkmode",
                "name": "Dark Reader",
                "description": "Dark mode for every website. Take care of your eyes.",
                "iconURL": "https://example.com/icon2.png",
                "downloadURL": "https://example.com/darkreader.appex",
                "version": "4.9.5"
            }
        ]
        """.data(using: .utf8)!
        
        do {
            self.extensions = try JSONDecoder().decode([ExtensionGalleryItem].self, from: mockData)
            self.isLoading = false
        } catch {
            print("Failed to load gallery: \(error)")
        }
    }
}

struct ExtensionGalleryCard: View {
    let item: ExtensionGalleryItem
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @State private var isInstalling = false

    var isInstalled: Bool {
        profileEnvironment.extensionManager.installedExtensions.contains { context in
            // Stable identifier check
            if let displayName = context.webExtension.displayName {
                return displayName == item.name
            }
            return false
        }
    }

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            AsyncImage(url: URL(string: item.iconURL)) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "puzzlepiece.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, height: 60)
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.headline)
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Spacer()
                
                if isInstalled {
                    Text("Installed")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(5)
                } else {
                    Button(action: install) {
                        if isInstalling {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Install")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isInstalling)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .alert("Installation Failed", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    private func install() {
        isInstalling = true
        Task {
            do {
                // In a real app, we would download the file from item.downloadURL.
                // For this implementation, we'll simulate the download process.
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(item.id)
                // (Simulated download logic here - for now we assume it exists or fail)
                
                try await profileEnvironment.extensionManager.installExtension(from: tempURL)
                await MainActor.run {
                    isInstalling = false
                }
            } catch {
                await MainActor.run {
                    isInstalling = false
                    errorMessage = error.localizedDescription
                    showError = true
                    AppLog.error("Installation failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
