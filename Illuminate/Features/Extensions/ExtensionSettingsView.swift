//
//  ExtensionSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import WebKit

struct ExtensionSettingsView: View {
    @Environment(ProfileEnvironment.self) var profileEnvironment: ProfileEnvironment
    @State private var selectedExtension: IdentifiableContext?
    @State private var showGallery = false
    @State private var installedExtensions: [WKWebExtensionContext] = []

    private var manager: ExtensionManager { profileEnvironment.extensionManager }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if showGallery {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            showGallery = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Extensions")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    Text("Extensions")
                        .font(.headline)
                        .transition(.opacity)
                }

                Spacer()

                if !showGallery {
                    Button {
                        Task { await manager.checkAndUpdateExtensions() }
                    } label: {
                        Group {
                            if manager.isCheckingForUpdates {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            }
                        }
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.isCheckingForUpdates || manager.isLoadingExtensions || profileEnvironment.isGuestSession)
                    .help(profileEnvironment.isGuestSession ? "Not available in private mode" : (manager.isCheckingForUpdates ? "Checking for updates…" : "Check for Updates"))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, MacDesign.Spacing.roomy)
            .padding(.vertical, MacDesign.Spacing.medium)
            .background(.bar)

            Divider()
            Group {
                if showGallery {
                    ExtensionGalleryView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                } else {
                    extensionBody
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $selectedExtension) { wrapper in
            ExtensionDetailView(context: wrapper.context)
                .environment(profileEnvironment)
        }
        .onChange(of: manager.enabledStateVersion) { _, _ in
            installedExtensions = manager.installedExtensions
        }
        .onAppear {
            installedExtensions = manager.installedExtensions
        }
    }

    @ViewBuilder
    private var extensionBody: some View {
        if manager.isLoadingExtensions {
            loadingState
        } else if profileEnvironment.isGuestSession {
            guestSessionView
        } else if installedExtensions.isEmpty {
            emptyState
        } else {
            extensionList
        }
    }

    private var loadingState: some View {
        VStack(spacing: MacDesign.Spacing.roomy) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading Extensions…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var guestSessionView: some View {
        VStack(spacing: MacDesign.Spacing.roomy) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: MacDesign.Spacing.tight) {
                Text("Extensions Disabled in Private Mode")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Extensions are not available during private browsing to protect your privacy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: MacDesign.Spacing.section) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: MacDesign.Spacing.tight) {
                Text("No Extensions Installed")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Browse the gallery to add extensions that enhance your browsing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    showGallery = true
                }
            } label: {
                Label("Browse Extension Gallery", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var extensionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MacDesign.Spacing.section) {
                if manager.isCheckingForUpdates {
                    HStack(spacing: MacDesign.Spacing.small) {
                        ProgressView().controlSize(.small)
                        Text("Checking for updates…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Installed — \(installedExtensions.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .padding(.horizontal, MacDesign.Spacing.small)

                    LazyVStack(spacing: 1) {
                        ForEach(installedExtensions, id: \.self) { context in
                            ExtensionSettingsRow(context: context)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedExtension = IdentifiableContext(context: context)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
                }

                if !manager.loadingErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Loading Errors", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                            .textCase(.uppercase)
                            .padding(.horizontal, MacDesign.Spacing.small)

                        LazyVStack(spacing: 1) {
                            ForEach(manager.loadingErrors) { error in
                                ExtensionErrorRow(error: error)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
                    }
                }

                HStack(spacing: MacDesign.Spacing.medium) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            showGallery = true
                        }
                    } label: {
                        Label("Browse Extension Gallery", systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(InternalPageChipButtonStyle(color: Color.accentColor))

                    Spacer()
                }
            }
            .padding(MacDesign.Spacing.page)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
