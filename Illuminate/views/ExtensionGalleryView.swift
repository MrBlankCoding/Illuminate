//
//  ExtensionGalleryView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/21/26.
//

import SwiftUI
import WebKit

struct ExtensionGalleryItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let iconURL: URL?
    let source: ExtensionPackageSource
}

enum ExtensionGalleryCatalog {
    static let items: [ExtensionGalleryItem] = [
        ExtensionGalleryItem(
            id: "ublock-origin-lite",
            name: "uBlock Origin Lite",
            description: "An efficient Manifest V3 content blocker that uses declarative rules to hide ads and trackers.",
            iconURL: URL(string: "https://raw.githubusercontent.com/gorhill/uBlock/master/src/img/icon_128.png"),
            source: .githubRelease(repository: "uBlockOrigin/uBOL-home", assetNameContains: "chromium.zip")
        ),
        ExtensionGalleryItem(
            id: "dark-reader",
            name: "Dark Reader",
            description: "Dark mode for every website. Take care of your eyes.",
            iconURL: URL(string: "https://raw.githubusercontent.com/darkreader/darkreader/main/src/ui/assets/images/darkreader-icon-128px.png"),
            source: .githubRelease(repository: "darkreader/darkreader", assetNameContains: "chrome-mv3.zip")
        )
    ]
}

struct ExtensionGalleryView: View {
    @EnvironmentObject var profileEnvironment: ProfileEnvironment

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                ForEach(ExtensionGalleryCatalog.items) { item in
                    ExtensionGalleryCard(item: item)
                        .environmentObject(profileEnvironment)
                }
            }
            .padding()
        }
        .navigationTitle("Extension Gallery")
    }
}

struct ExtensionGalleryCard: View {
    let item: ExtensionGalleryItem
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @State private var isInstalling = false
    @State private var errorMessage: String?
    @State private var showError = false

    var isInstalled: Bool {
        profileEnvironment.extensionManager.installedExtensions.contains { context in
            profileEnvironment.extensionManager.matchesGalleryItem(item, context: context)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            AsyncImage(url: item.iconURL) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "puzzlepiece.fill")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.headline)
                Text(item.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                if isInstalled {
                    Button(action: uninstall) {
                        Text("Uninstall")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                let packageURL = try await ExtensionPackageDownloader.downloadUnpackedPackage(from: item.source)
                try await profileEnvironment.extensionManager.installExtension(
                    from: packageURL,
                    preferredIdentifier: item.id
                )
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

    private func uninstall() {
        guard let context = profileEnvironment.extensionManager.installedExtensions.first(where: { context in
            profileEnvironment.extensionManager.matchesGalleryItem(item, context: context)
        }) else {
            return
        }
        profileEnvironment.extensionManager.uninstallExtension(context)
    }
}
