//
//  ExtensionGalleryView.swift
//  Illuminate
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
            description: "An efficient Manifest V3 content blocker that uses declarative rules to eliminate ads and trackers — with no background permissions needed.",
            iconURL: URL(string: "https://raw.githubusercontent.com/gorhill/uBlock/master/src/img/icon_128.png"),
            source: .githubRelease(repository: "uBlockOrigin/uBOL-home", assetNameContains: "chromium.zip")
        ),
        ExtensionGalleryItem(
            id: "dark-reader",
            name: "Dark Reader",
            description: "Applies a gentle dark mode to every website. Adjustable brightness, contrast, and sepia filters — your eyes will thank you.",
            iconURL: URL(string: "https://raw.githubusercontent.com/darkreader/darkreader/main/src/ui/assets/images/darkreader-icon-128px.png"),
            source: .githubRelease(repository: "darkreader/darkreader", assetNameContains: "chrome-mv3.zip")
        ),
    ]
}

struct ExtensionGalleryView: View {
    @EnvironmentObject var profileEnvironment: ProfileEnvironment

    var body: some View {
        Group {
            if profileEnvironment.extensionManager.isLoadingExtensions {
                loadingState
            } else {
                galleryGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Extension Gallery")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                EmptyView()
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Loading Extensions…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var galleryGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Subtitle / count line
                Text("\(ExtensionGalleryCatalog.items.count) extensions available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300, maximum: 440), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(ExtensionGalleryCatalog.items) { item in
                        ExtensionGalleryCard(item: item)
                            .environmentObject(profileEnvironment)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ExtensionGalleryCard: View {
    let item: ExtensionGalleryItem
    @EnvironmentObject var profileEnvironment: ProfileEnvironment

    @State private var installState: InstallState = .idle
    @State private var installedContext: WKWebExtensionContext?
    @State private var showError = false
    @State private var errorMessage: String?

    private enum InstallState: Equatable {
        case idle, installing, installed, failed
    }

    private var isInstalled: Bool { installedContext != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: icon + name / description
            HStack(alignment: .top, spacing: 14) {
                iconView
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding([.top, .horizontal], 18)

            Spacer(minLength: 12)

            Divider()
                .padding(.horizontal, 18)

            HStack {
                statusBadge
                Spacer(minLength: 0)
                actionButton
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }

        .frame(height: 190)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isInstalled ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.12),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .alert("Installation Failed", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .onAppear(perform: syncInstalledState)
        .onReceive(profileEnvironment.extensionManager.$installedExtensions) { _ in
            syncInstalledState()
        }
    }

    private var iconView: some View {
        AsyncImage(url: item.iconURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            case .failure:
                iconFallback
            case .empty:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            @unknown default:
                iconFallback
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var iconFallback: some View {
        Image(systemName: "puzzlepiece.fill")
            .font(.system(size: 22))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isInstalled {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.green)
        } else if installState == .failed {
            Label("Failed", systemImage: "xmark.circle.fill")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isInstalled {
            Button(role: .destructive, action: uninstall) {
                Label("Uninstall", systemImage: "trash")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .transition(.opacity)
        } else {
            Button(action: install) {
                Group {
                    if installState == .installing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Installing…")
                        }
                    } else {
                        Label("Install", systemImage: "plus")
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(installState == .installing)
            .transition(.opacity)
        }
    }

    private func syncInstalledState() {
        installedContext = profileEnvironment.extensionManager.installedExtensions.first {
            profileEnvironment.extensionManager.matchesGalleryItem(item, context: $0)
        }
        if installedContext != nil, installState != .idle {
            withAnimation { installState = .installed }
        }
    }

    private func install() {
        guard installState != .installing else { return }
        withAnimation { installState = .installing }

        Task {
            do {
                let packageURL = try await ExtensionPackageDownloader.downloadUnpackedPackage(from: item.source)
                _ = try await profileEnvironment.extensionManager.installExtension(
                    from: packageURL,
                    preferredIdentifier: item.id,
                    source: item.source
                )
                withAnimation { installState = .installed }
            } catch {
                AppLog.error("Gallery install failed for '\(item.id)': \(error.localizedDescription)")
                withAnimation { installState = .failed }
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func uninstall() {
        guard let context = installedContext else { return }
        withAnimation {
            profileEnvironment.extensionManager.uninstallExtension(context)
            installedContext = nil
            installState = .idle
        }
    }
}
