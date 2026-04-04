//
//  SettingsView.swift
//  Illuminate
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @Environment(\.modelContext) private var modelContext

    @Query private var passwords: [Password]

    @Namespace private var tabSelectionAnimation
    @State private var selectedTab: SettingsTab = .appearance
    @State private var passwordSearchText = ""
    @StateObject private var downloadManager = DownloadManager.shared

    private var filteredPasswords: [Password] {
        guard environment.isGuestSession == false else { return [] }

        let scopedPasswords = passwords.filter {
            $0.profileID == environment.profile.id || $0.profileID == nil
        }
        let query = passwordSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return scopedPasswords }

        return scopedPasswords.filter {
            $0.url.lowercased().contains(query) || $0.username.lowercased().contains(query)
        }
    }

    private var accentHexLabel: String {
        "#\(tabManager.windowThemeColor.toHex() ?? "89BBFF")"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundDecor

                HStack(spacing: 24) {
                    sidebarRail
                        .frame(width: min(max(geometry.size.width * 0.24, 230), 280))

                    mainContent
                }
                .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgBase)
            .accessibilityIdentifier("settings.root")
        }
    }

    private var backgroundDecor: some View {
        ZStack {
            LinearGradient(
                colors: [
                    tabManager.windowThemeColor.opacity(0.18),
                    Color.bgBase,
                    Color.bgBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tabManager.windowThemeColor.opacity(0.16))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: -260, y: -240)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 260, y: 220)
        }
        .ignoresSafeArea()
    }

    private var sidebarRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            profileCard
            navigationCard
            Spacer(minLength: 0)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tabManager.windowThemeColor.opacity(0.95),
                                    tabManager.windowThemeColor.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: environment.profile.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.profile.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground(cornerRadius: 24))
    }

    private var navigationCard: some View {
        VStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                tabRailButton(tab)
            }
        }
        .padding(16)
        .background(panelBackground(cornerRadius: 24))
    }

    private func tabRailButton(_ tab: SettingsTab) -> some View {
        let active = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(active ? Color.white.opacity(0.16) : Color.primary.opacity(0.05))

                    Image(systemName: tab.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? .white : Color.textSecondary)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? .white : Color.textPrimary)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    if active {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tabManager.windowThemeColor.opacity(0.95),
                                        tabManager.windowThemeColor.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .matchedGeometryEffect(id: "settings-tab-selection", in: tabSelectionAnimation)
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.clear)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
        .accessibilityIdentifier("settings.tab.\(tab.title.lowercased())")
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                activeTabContent
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .appearance:
            appearanceTab
        case .shortcuts:
            shortcutsTab
        case .passwords:
            passwordsTab
        case .cookies:
            cookiesTab
        case .downloads:
            downloadsTab
        case .additional:
            additionalTab
        }
    }

    private func panelSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground(cornerRadius: 26))
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }

    private func metricsPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .kerning(1.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func infoRow(title: String, tint: Color? = nil, trailing: @escaping () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint ?? Color.textPrimary)

            Spacer()

            trailing()
        }
    }

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            panelSection {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        ForEach(TabManager.UIStyle.allCases, id: \.rawValue) { style in
                            themeCard(style)
                        }
                    }

                    Divider().opacity(0.22)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Accent tones")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(accentHexLabel)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(tabManager.windowThemeColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(tabManager.windowThemeColor.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        if !tabManager.backgroundImagePalette.isEmpty {
                            colorRow(title: "From background", colors: tabManager.backgroundImagePalette)
                        }

                        colorRow(title: "Presets", colors: accentPresets)
                    }
                }
            }

            panelSection {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.primary.opacity(0.05))

                            HStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundStyle(Color.textSecondary)
                                TextField("Paste an image URL or pick a local file", text: $tabManager.backgroundImageURL)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 14)
                        }
                        .frame(height: 48)

                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.allowsMultipleSelection = false
                            panel.allowedContentTypes = [.image]

                            if panel.runModal() == .OK, let url = panel.url {
                                tabManager.backgroundImageURL = url.absoluteString
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles.tv")
                                Text("Browse")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(tabManager.windowThemeColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .hoverCursor(.pointingHand)
                    }

                    infoRow(title: "Show image behind sidebar") {
                        Toggle("", isOn: $tabManager.showBackgroundBehindSidebar)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                            .hoverCursor(.pointingHand)
                    }
                }
            }
        }
    }

    private func themeCard(_ style: TabManager.UIStyle) -> some View {
        let active = tabManager.userInterfaceStyle == style

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                tabManager.userInterfaceStyle = style
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(themePreviewFill(for: style))
                        .frame(height: 92)
                        .overlay {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(style == .dark ? 0.14 : 0.62))
                                    .frame(height: 12)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 12)

                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(style == .dark ? 0.12 : 0.56))
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(style == .dark ? 0.08 : 0.42))
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                            }
                        }

                    if active {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(style.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(active ? tabManager.windowThemeColor.opacity(0.14) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(active ? tabManager.windowThemeColor.opacity(0.85) : Color.primary.opacity(0.07), lineWidth: active ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private func themePreviewFill(for style: TabManager.UIStyle) -> LinearGradient {
        switch style {
        case .dark:
            return LinearGradient(
                colors: [Color.black.opacity(0.95), Color.gray.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            return LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .system:
            return LinearGradient(
                colors: [Color.gray.opacity(0.78), Color.white.opacity(0.95), Color.black.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func colorRow(title: String, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        colorSwatch(color)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func colorSwatch(_ color: Color) -> some View {
        let active = tabManager.windowThemeColor == color

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                tabManager.windowThemeColor = color
            }
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(active ? 0.95 : 0.35), lineWidth: active ? 2 : 1)
                    )
                    .shadow(color: color.opacity(active ? 0.45 : 0.18), radius: active ? 10 : 5)

                if active {
                    Text("Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                } else {
                    Text(" ")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(active ? 0.06 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }

    private var shortcutsTab: some View {
        let shortcuts: [(String, String)] = [
            ("New Tab", "⌘ T"),
            ("Close Tab", "⌘ W"),
            ("Reopen Closed Tab", "⌘ ⇧ T"),
            ("Bookmark Tab", "⌘ B"),
            ("Focus URL Bar", "⌘ L"),
            ("Refresh Page", "⌘ R"),
            ("Find in Page", "⌘ F"),
            ("Toggle Full Screen", "⌘ ⇧ F"),
            ("Toggle Sidebar", "⌘ S"),
            ("Zoom In", "⌘ +"),
            ("Zoom Out", "⌘ −"),
            ("Reset Zoom", "⌘ 0"),
            ("Go Back", "⌘ ←"),
            ("Go Forward", "⌘ →"),
            ("Developer Tools", "⌘ ⇧ I")
        ]

        return panelSection {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {
                ForEach(shortcuts, id: \.0) { shortcut in
                    HStack {
                        HStack {
                            Text(shortcut.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(shortcut.1)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(tabManager.windowThemeColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(tabManager.windowThemeColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private var passwordsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            panelSection {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)

                            TextField("Search URLs or usernames", text: $passwordSearchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium))
                                .accessibilityIdentifier("settings.passwords.searchField")
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        metricsPill(value: "\(filteredPasswords.count)", label: "Visible")
                    }

                    if filteredPasswords.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: environment.isGuestSession ? "person.fill.questionmark" : (passwordSearchText.isEmpty ? "lock.slash" : "magnifyingglass.circle"))
                                .font(.system(size: 30))
                                .foregroundStyle(tabManager.windowThemeColor.opacity(0.7))
                            Text(
                                environment.isGuestSession
                                    ? "Guest sessions do not keep saved passwords"
                                    : (passwordSearchText.isEmpty ? "No saved passwords yet" : "No matching passwords")
                            )
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredPasswords) { password in
                                passwordRow(password)
                            }
                        }
                    }
                }
            }
        }
    }

    private func passwordRow(_ password: Password) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(tabManager.windowThemeColor.opacity(0.12))

                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tabManager.windowThemeColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(password.url)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(password.username)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(password.passwordData, forType: .string)
            } label: {
                actionCapsule(icon: "doc.on.doc", title: "Copy", tint: tabManager.windowThemeColor)
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .help("Copy password")

            Button(role: .destructive) {
                modelContext.delete(password)
                try? modelContext.save()
            } label: {
                actionCapsule(icon: "trash", title: "Delete", tint: .red.opacity(0.72))
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .help("Delete")
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func actionCapsule(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(tint.opacity(0.1))
        .clipShape(Capsule())
    }

    private var cookiesTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            panelSection {
                VStack(alignment: .leading, spacing: 16) {
                    infoRow(title: "Enable cookies") {
                        Toggle("", isOn: Binding(
                            get: { environment.webKitManager.cookiesEnabled },
                            set: { environment.webKitManager.cookiesEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                    }

                    Divider().opacity(0.22)

                    Button(role: .destructive) {
                        CookieViewModel().clearAllCookies(with: environment.webKitManager)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                            Text("Clear all cookies and website data")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(14)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .hoverCursor(.pointingHand)
                }
            }
        }
    }

    private var additionalTab: some View {
        panelSection {
            VStack(alignment: .leading, spacing: 16) {
                infoRow(title: "Enable ad blocker") {
                    Toggle("", isOn: Binding(
                        get: { environment.adBlockService.isEnabled },
                        set: { environment.adBlockService.isEnabled = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                    .hoverCursor(.pointingHand)
                }

                infoRow(title: "Block cross-site redirects") {
                    Toggle("", isOn: Binding(
                        get: { environment.redirectProtectionService.isEnabled },
                        set: { environment.redirectProtectionService.isEnabled = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                    .hoverCursor(.pointingHand)
                }

                HStack(spacing: 12) {
                    protectionBadge(
                        icon: "shield.lefthalf.filled",
                        title: environment.adBlockService.isEnabled ? "Shield up" : "Paused"
                    )

                    protectionBadge(
                        icon: "arrow.trianglehead.branch",
                        title: environment.redirectProtectionService.isEnabled ? "Redirects blocked" : "Redirects allowed"
                    )
                }
            }
        }
    }

    private var downloadsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            panelSection {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Safer downloads")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Block installers, app bundles, and scripts before they are saved locally.")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { downloadManager.preferences.safeDownloadsOnly },
                                set: { downloadManager.setSafeDownloadsOnly($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                        .accessibilityIdentifier("settings.downloads.safeToggle")
                    }

                    Divider().opacity(0.22)

                    infoRow(title: "Reveal finished downloads in Finder") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { downloadManager.preferences.revealInFinderWhenFinished },
                                set: { downloadManager.setRevealInFinderWhenFinished($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                        .accessibilityIdentifier("settings.downloads.revealToggle")
                    }

                    infoRow(title: "Ask where to save each file") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { downloadManager.preferences.askWhereToSave },
                                set: { downloadManager.setAskWhereToSave($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: tabManager.windowThemeColor))
                        .hoverCursor(.pointingHand)
                        .accessibilityIdentifier("settings.downloads.askWhereToSave")
                    }

                    infoRow(title: "Default save location") {
                        HStack(spacing: 10) {
                            Text(downloadManager.downloadDirectoryURL.path)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button("Choose Folder") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.canCreateDirectories = true
                                panel.directoryURL = downloadManager.downloadDirectoryURL

                                if panel.runModal() == .OK, let url = panel.url {
                                    downloadManager.setDownloadDirectory(url)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tabManager.windowThemeColor)
                            .accessibilityIdentifier("settings.downloads.chooseFolder")

                            Button("Reset") {
                                downloadManager.resetDownloadDirectory()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityIdentifier("settings.downloads.resetFolder")
                        }
                    }
                }
            }
        }
    }

    private func protectionBadge(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tabManager.windowThemeColor)
                .frame(width: 36, height: 36)
                .background(tabManager.windowThemeColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private let accentPresets: [Color] = [
        Color(red: 0.537, green: 0.733, blue: 1.0),
        Color(red: 0.8, green: 0.6, blue: 0.9),
        Color(red: 1.0, green: 0.6, blue: 0.6),
        Color(red: 1.0, green: 0.8, blue: 0.5),
        Color(red: 0.6, green: 0.9, blue: 0.7),
        Color(red: 0.5, green: 0.5, blue: 0.5),
        Color(red: 0.9, green: 0.4, blue: 0.7),
        Color(red: 0.4, green: 0.8, blue: 0.9),
        Color(red: 0.7, green: 0.9, blue: 0.4)
    ]
}

private enum SettingsTab: Int, CaseIterable, Identifiable {
    case appearance
    case shortcuts
    case passwords
    case cookies
    case downloads
    case additional

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .shortcuts:
            return "Shortcuts"
        case .passwords:
            return "Passwords"
        case .cookies:
            return "Cookies"
        case .downloads:
            return "Downloads"
        case .additional:
            return "Protection"
        }
    }

    var icon: String {
        switch self {
        case .appearance:
            return "paintpalette.fill"
        case .shortcuts:
            return "command"
        case .passwords:
            return "key.fill"
        case .cookies:
            return "circle.hexagongrid.fill"
        case .downloads:
            return "arrow.down.circle.fill"
        case .additional:
            return "shield.lefthalf.filled"
        }
    }
}

private extension TabManager.UIStyle {
    var title: String {
        switch self {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        case .system:
            return "System"
        }
    }
}
