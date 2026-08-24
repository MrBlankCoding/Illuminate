//
//  ExtensionGalleryView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

// TODO
// way to overcomplicated
// Need to simplify

import Combine
import SwiftUI
import WebKit

struct ExtensionGalleryItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let iconURL: URL?
    let source: ExtensionPackageSource
    let fallbackAssetNameCandidates: [String]
    let externalInfoURL: URL?

    init(
        id: String,
        name: String,
        description: String,
        iconURL: URL?,
        source: ExtensionPackageSource,
        fallbackAssetNameCandidates: [String] = [],
        externalInfoURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconURL = iconURL
        self.source = source
        self.fallbackAssetNameCandidates = fallbackAssetNameCandidates
        self.externalInfoURL = externalInfoURL
    }
}

@MainActor
final class RemoteGalleryCatalog: ObservableObject {
    private static let remoteCatalogURL: URL? = nil
    static let ublock = ExtensionGalleryItem(
        id: "ublock-origin-lite",
        name: "uBlock Origin Lite",
        description: "An efficient Manifest V3 content blocker that eliminates ads and trackers using declarative rules — with no background permissions needed.",
        iconURL: URL(string: "https://raw.githubusercontent.com/gorhill/uBlock/master/src/img/icon_128.png"),
        source: .githubRelease(repository: "uBlockOrigin/uBOL-home", assetNameContains: "safari.zip"),
        fallbackAssetNameCandidates: ["webkit.zip", "chromium.mv3.zip"],
        externalInfoURL: URL(string: "https://apps.apple.com/us/app/ublock-origin-lite/id6745342698")
    )
    static let darkreader = ExtensionGalleryItem(
        id: "darkreader",
        name: "Dark Reader",
        description: "Dark mode for every website. Care for your eyes, use dark theme for night and daily browsing.",
        iconURL: URL(string: "https://raw.githubusercontent.com/darkreader/darkreader/master/src/icons/icon_128.png"),
        source: .githubRelease(repository: "darkreader/darkreader", assetNameContains: "chrome-mv3"),
        fallbackAssetNameCandidates: ["chrome", "firefox-mv3", "firefox"],
        externalInfoURL: URL(string: "https://darkreader.org/")
    )
    private static let hardcodedItems: [ExtensionGalleryItem] = [
        ublock,
        darkreader,
    ]

    enum FetchState { case idle, loading, done, failed }

    @Published private(set) var items: [ExtensionGalleryItem] = hardcodedItems
    @Published private(set) var fetchState: FetchState = .idle

    func load() {
        guard case .idle = fetchState else { return }
        guard let url = Self.remoteCatalogURL else {
            fetchState = .done   // no remote URL configured — hardcoded list is final
            return
        }
        fetchState = .loading
        Task { await fetch(from: url) }
    }

    private func fetch(from url: URL) async {
        do {
            var request = URLRequest(url: url)
            request.setValue("Illuminate", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode([RemoteGalleryEntry].self, from: data)
            let remoteItems = decoded.compactMap(\.galleryItem)
            var seen = Set(Self.hardcodedItems.map(\.id))
            var merged = Self.hardcodedItems
            for item in remoteItems where !seen.contains(item.id) {
                seen.insert(item.id)
                merged.append(item)
            }
            items = merged
            fetchState = .done
        } catch {
            fetchState = .failed
            AppLog.warning("Remote extension catalog fetch failed: \(error.localizedDescription)")
        }
    }
}

private struct RemoteGalleryEntry: Decodable {
    let id: String
    let name: String
    let description: String
    let iconURL: String?
    let githubRepository: String
    let assetNameContains: String
    let fallbackAssetNameCandidates: [String]?
    let externalInfoURL: String?

    var galleryItem: ExtensionGalleryItem? {
        ExtensionGalleryItem(
            id: id,
            name: name,
            description: description,
            iconURL: iconURL.flatMap { URL(string: $0) },
            source: .githubRelease(
                repository: githubRepository,
                assetNameContains: assetNameContains
            ),
            fallbackAssetNameCandidates: fallbackAssetNameCandidates ?? [],
            externalInfoURL: externalInfoURL.flatMap { URL(string: $0) }
        )
    }
}

struct ExtensionGalleryView: View {
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @StateObject private var catalog = RemoteGalleryCatalog()

    var body: some View {
        galleryGrid
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { catalog.load() }
    }

    private var galleryGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Text("\(catalog.items.count) extension\(catalog.items.count == 1 ? "" : "s") available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if case .loading = catalog.fetchState {
                        ProgressView().controlSize(.mini)
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300, maximum: 440), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(catalog.items) { item in
                        ExtensionGalleryCard(item: item)
                            .environmentObject(profileEnvironment)
                    }
                }

                if case .failed = catalog.fetchState {
                    Label("Couldn't load more extensions. Showing essentials only.", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }

        .clipped()
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
        case idle, installing, installed, failed, unavailable
    }

    private var isInstalled: Bool { installedContext != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        } message: { msg in Text(msg) }
        .onAppear(perform: syncInstalledState)
        .onReceive(profileEnvironment.extensionManager.$installedExtensions) { _ in
            syncInstalledState()
        }
        .onReceive(profileEnvironment.extensionManager.$pinnedExtensions) { _ in
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
        } else if installState == .unavailable {
            Label("Not available for direct install", systemImage: "info.circle")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
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
        } else if installState == .unavailable, let url = item.externalInfoURL {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("View in App Store", systemImage: "arrow.up.forward.square")
                    .font(.subheadline)
                    .fontWeight(.medium)
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
        let matchedContext = profileEnvironment.extensionManager.installedExtensions.first {
            profileEnvironment.extensionManager.matchesGalleryItem(item, context: $0)
        }
        let wasInstalled = installedContext != nil
        installedContext = matchedContext

        if matchedContext != nil {
            if installState != .installed {
                withAnimation { installState = .installed }
            }
        } else if wasInstalled {
            withAnimation { installState = .idle }
        }
    }

    private var candidateSources: [ExtensionPackageSource] {
        guard
            case .githubRelease(let repository, _) = item.source,
            !item.fallbackAssetNameCandidates.isEmpty
        else {
            return [item.source]
        }
        let fallbacks = item.fallbackAssetNameCandidates.map {
            ExtensionPackageSource.githubRelease(repository: repository, assetNameContains: $0)
        }
        return [item.source] + fallbacks
    }

    private func install() {
        guard installState != .installing else { return }
        withAnimation { installState = .installing }
        Task {
            var lastError: Error?
            for candidate in candidateSources {
                do {
                    let packageURL = try await ExtensionPackageDownloader.downloadUnpackedPackage(from: candidate)
                    let context = try await profileEnvironment.extensionManager.installExtension(
                        from: packageURL,
                        preferredIdentifier: item.id,
                        source: candidate
                    )
                    // Auto-pin newly installed extensions
                    profileEnvironment.extensionManager.setPinned(context, pinned: true)
                    withAnimation { installState = .installed }
                    return
                } catch {
                    lastError = error
                    continue // try the next candidate asset name, if any
                }
            }

            AppLog.error("Gallery install failed for '\(item.id)': \(lastError?.localizedDescription ?? "no matching release asset")")
            if item.externalInfoURL != nil {
                withAnimation { installState = .unavailable }
            } else {
                withAnimation { installState = .failed }
                errorMessage = lastError?.localizedDescription ?? "No compatible download was found for this extension."
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