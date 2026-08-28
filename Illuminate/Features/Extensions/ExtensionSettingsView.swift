//
//  ExtensionSettingsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import WebKit

struct ExtensionSettingsView: View {
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
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
                    .disabled(manager.isCheckingForUpdates || manager.isLoadingExtensions)
                    .help(manager.isCheckingForUpdates ? "Checking for updates…" : "Check for Updates")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()
            Group {
                if showGallery {
                    ExtensionGalleryView()
                        .transition(.asymmetric(
                            insertion:  .move(edge: .trailing),
                            removal:    .move(edge: .trailing)
                        ))
                } else {
                    extensionBody
                        .transition(.asymmetric(
                            insertion:  .move(edge: .leading),
                            removal:    .move(edge: .leading)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $selectedExtension) { wrapper in
            ExtensionDetailView(context: wrapper.context)
                .environmentObject(profileEnvironment)
        }
        .onReceive(manager.$installedExtensions) { extensions in
            installedExtensions = extensions
        }
        .onReceive(manager.$enabledStateVersion) { _ in
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
        } else if installedExtensions.isEmpty {
            emptyState
        } else {
            extensionList
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading Extensions…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
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
            LazyVStack(alignment: .leading, spacing: 20) {
                if manager.isCheckingForUpdates {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Checking for updates…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Installed — \(installedExtensions.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    LazyVStack(spacing: 1) {
                        ForEach(installedExtensions, id: \.self) { context in
                            ExtensionSettingsRow(context: context)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedExtension = IdentifiableContext(context: context)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !manager.loadingErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Loading Errors", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)

                        LazyVStack(spacing: 1) {
                            ForEach(manager.loadingErrors) { error in
                                ExtensionErrorRow(error: error)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                HStack(spacing: 10) {
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
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ExtensionSettingsRow: View {
    let context: WKWebExtensionContext
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @State private var isEnabled: Bool = false
    @State private var isPinned: Bool = false

    private var currentEnabledState: Bool {
        profileEnvironment.extensionManager.isEnabled(context)
    }

    private var currentPinnedState: Bool {
        profileEnvironment.extensionManager.isPinned(context)
    }

    var body: some View {
        HStack(spacing: 12) {
            extensionIcon
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(context.webExtension.displayName ?? "Unknown Extension")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if profileEnvironment.extensionManager.isBundled(context) {
                        Text("BUILT-IN")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text("v\(context.webExtension.version ?? "1.0")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if !isEnabled {
                Text("Off")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                Button {
                    isPinned.toggle()
                    profileEnvironment.extensionManager.setPinned(context, pinned: isPinned)
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 13))
                        .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin from toolbar" : "Pin to toolbar")

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        profileEnvironment.extensionManager.setEnabled(context, enabled: newValue)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(.regularMaterial)
        .opacity(isEnabled ? 1.0 : 0.65)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(context.webExtension.displayName ?? "Extension"), \(isEnabled ? "enabled" : "disabled")")
        .onReceive(profileEnvironment.extensionManager.$enabledStateVersion) { _ in
            isEnabled = currentEnabledState
        }
        .onReceive(profileEnvironment.extensionManager.$pinnedExtensions) { _ in
            isPinned = currentPinnedState
        }
        .onAppear {
            isEnabled = currentEnabledState
            isPinned = currentPinnedState
        }
    }

    @ViewBuilder
    private var extensionIcon: some View {
        if let icon = context.webExtension.icon(for: CGSize(width: 36, height: 36)) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay(
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                )
        }
    }
}

private struct ExtensionErrorRow: View {
    let error: ExtensionManager.ExtensionLoadingError

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Text(error.extensionName ?? error.extensionIdentifier)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            Text(error.error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }
}

struct ExtensionDetailView: View {
    let context: WKWebExtensionContext
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @Environment(\.dismiss) var dismiss
    @State private var isUninstalling = false
    @State private var showUninstallConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(context.webExtension.displayName ?? "Extension")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    Divider()
                    descriptionSection
                    permissionsSection
                    Spacer(minLength: 0)
                    actionsSection
                }
                .padding(20)
            }
        }
        .frame(width: 480)
        .frame(minHeight: 480, maxHeight: 640)
        .confirmationDialog(
            "Uninstall \(context.webExtension.displayName ?? "this extension")?",
            isPresented: $showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                isUninstalling = true
                profileEnvironment.extensionManager.uninstallExtension(context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the extension and its data.")
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            extensionIcon(size: 64, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 5) {
                Text(context.webExtension.displayName ?? "Unknown Extension")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Version \(context.webExtension.version ?? "1.0")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let author = context.webExtension.manifest["author"] as? String {
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if profileEnvironment.extensionManager.isBundled(context) {
                    Label("Built-in extension", systemImage: "seal.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Description", systemImage: "text.alignleft")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(context.webExtension.displayDescription ?? "No description available.")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Permissions", systemImage: "lock.shield")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            let grantedPerms    = Set(context.grantedPermissions.keys)
            let requestedOnly   = context.webExtension.requestedPermissions.subtracting(grantedPerms)
            let grantedPatterns = Set(context.grantedPermissionMatchPatterns.keys)

            if grantedPerms.isEmpty && requestedOnly.isEmpty && grantedPatterns.isEmpty {
                Text("No special permissions requested.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            } else {
                VStack(spacing: 8) {
                    if !grantedPerms.isEmpty {
                        PermissionGroup(
                            title: "Granted",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            items: grantedPerms.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
                        )
                    }
                    if !requestedOnly.isEmpty {
                        PermissionGroup(
                            title: "Requested — Not Granted",
                            icon: "exclamationmark.circle.fill",
                            color: .orange,
                            items: requestedOnly.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
                        )
                    }
                    if !grantedPatterns.isEmpty {
                        PermissionGroup(
                            title: "Site Access",
                            icon: "globe",
                            color: .blue,
                            items: grantedPatterns.sorted { $0.description < $1.description }.map(\.description)
                        )
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if hasOptionsPage {
                Button {
                    profileEnvironment.extensionManager.openOptionsPage(for: context)
                    dismiss()
                } label: {
                    Label("Extension Options", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                Group {
                    if isUninstalling {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Uninstalling…")
                        }
                    } else {
                        Label("Uninstall Extension", systemImage: "trash")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(isUninstalling || profileEnvironment.extensionManager.isBundled(context))
        }
    }

    @ViewBuilder
    private func extensionIcon(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let icon = context.webExtension.icon(for: CGSize(width: size, height: size)) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var hasOptionsPage: Bool {
        let manifest = context.webExtension.manifest
        return manifest["options_page"] != nil
            || (manifest["options_ui"] as? [String: Any])?["page"] != nil
    }
}

private struct PermissionGroup: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(color.opacity(0.5))
                            .frame(width: 5, height: 5)
                        Text(item)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct IdentifiableContext: Identifiable {
    let context: WKWebExtensionContext
    var id: ObjectIdentifier { ObjectIdentifier(context) }
}