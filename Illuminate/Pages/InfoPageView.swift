//
//  InfoPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/20/26.
//

import AppKit
import SwiftUI
import WebKit

// illuminate://info

struct InfoPageView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var environment: ProfileEnvironment
    @EnvironmentObject private var webKitManager: WebKitManager
    @EnvironmentObject private var trackerBlockingService: TrackerBlockingService
    @EnvironmentObject private var websitePermissionService: WebsitePermissionService
    @EnvironmentObject private var canvasFingerprintingService: CanvasFingerprintingService
    @EnvironmentObject private var historyManager: HistoryManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var userAgent: String = "Loading..."
    @State private var didCopyDiagnostics = false
    @State private var didCopyUserAgent = false
    @State private var cachePurged = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    var body: some View {
        InternalPage(
            icon: "info.circle.fill",
            title: "Browser Info & Diagnostics",
            accentColor: tabManager.windowThemeColor
        ) {
            VStack(alignment: .leading, spacing: 24) {
                actionsHeaderSection
                userAgentSection
                profileAndSessionSection
                tabsAndWindowStateSection
                protectionServicesSection
                systemDiagnosticsSection
            }
        }
        .task {
            await loadUserAgent()
        }
    }

    private var actionsHeaderSection: some View {
        InternalPageRow {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Diagnostics & Debugging")
                        .font(.system(size: 14, weight: .medium))
                    Text("Inspect internal state, copy configuration report, or manage diagnostic caches.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    purgeCaches()
                } label: {
                    Label(cachePurged ? "Caches Purged" : "Purge Caches", systemImage: cachePurged ? "checkmark" : "trash")
                }
                .buttonStyle(InternalPageChipButtonStyle(color: cachePurged ? .green : .secondary))

                Button {
                    copyDiagnosticsToPasteboard()
                } label: {
                    Label(didCopyDiagnostics ? "Copied JSON" : "Copy All Info", systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(InternalPageChipButtonStyle(color: didCopyDiagnostics ? .green : tabManager.windowThemeColor))
            }
        }
    }

    private var userAgentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "User Agent & Web Engine")

            InternalPageRow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("User Agent String")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Button {
                            copyToPasteboard(userAgent)
                            didCopyUserAgent = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                didCopyUserAgent = false
                            }
                        } label: {
                            Label(didCopyUserAgent ? "Copied" : "Copy", systemImage: didCopyUserAgent ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(InternalPageChipButtonStyle(color: didCopyUserAgent ? .green : tabManager.windowThemeColor))
                    }

                    Text(userAgent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            InternalPageRow {
                VStack(spacing: 8) {
                    infoKeyValueRow(title: "Website Data Store", value: environment.isGuestSession ? "Non-Persistent (In-Memory / Private)" : "Persistent (\(environment.profile.name))")
                    Divider()
                    infoKeyValueRow(title: "Cookies Enabled", value: environment.webKitManager.cookiesEnabled ? "Yes" : "No")
                    Divider()
                    infoKeyValueRow(title: "HTTPS-Only Mode", value: environment.webKitManager.httpsOnlyEnabled ? "Enabled" : "Disabled")
                    Divider()
                    infoKeyValueRow(
                        title: "Dynamic URLCache Limits",
                        value: "Memory: \(URLCache.shared.memoryCapacity / 1024 / 1024) MB · Disk: \(URLCache.shared.diskCapacity / 1024 / 1024) MB"
                    )
                }
            }
        }
    }

    private var profileAndSessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "Profile & Session")

            InternalPageRow {
                VStack(spacing: 8) {
                    infoKeyValueRow(title: "Profile Name", value: environment.profile.name)
                    Divider()
                    infoKeyValueRow(title: "Profile Identifier", value: environment.profile.id.uuidString)
                    Divider()
                    infoKeyValueRow(title: "Session Type", value: environment.isGuestSession ? "Guest Session (Ephemeral)" : "Standard Profile")
                    Divider()
                    infoKeyValueRow(title: "Session ID", value: environment.sessionIdentifier?.uuidString ?? "Default")
                    Divider()
                    infoKeyValueRow(title: "Theme Accent Color", value: tabManager.windowThemeColor.toHex() ?? "Custom")
                    Divider()
                    infoKeyValueRow(title: "Appearance Mode", value: tabManager.userInterfaceStyle.rawValue.capitalized)
                }
            }
        }
    }

    private var tabsAndWindowStateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "Tabs & Navigation State")

            InternalPageRow {
                VStack(spacing: 8) {
                    infoKeyValueRow(title: "Open Tabs", value: "\(tabManager.tabs.count) tab\(tabManager.tabs.count == 1 ? "" : "s")")
                    Divider()
                    infoKeyValueRow(title: "Active Tab Title", value: tabManager.activeTab?.title.isEmpty == false ? tabManager.activeTab!.title : "Untitled")
                    Divider()
                    infoKeyValueRow(title: "Active Tab URL", value: tabManager.activeTab?.url?.absoluteString ?? "illuminate://new")
                    Divider()
                    infoKeyValueRow(title: "Active Tab ID", value: tabManager.activeTabID?.uuidString ?? "None")
                    Divider()
                    infoKeyValueRow(
                        title: "Tab Groups",
                        value: "\(tabManager.tabGroupManager.groups.count) active group\(tabManager.tabGroupManager.groups.count == 1 ? "" : "s")"
                    )
                    Divider()
                    infoKeyValueRow(title: "Full Screen Mode", value: tabManager.isFullScreen ? "Yes" : "No")
                }
            }
        }
    }

    private var protectionServicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "Protection Services")

            InternalPageRow {
                VStack(spacing: 8) {
                    let blockedTrackers = environment.trackerBlockingService.domainStats.filter(\.isBlocked).count
                    let totalTrackers = environment.trackerBlockingService.domainStats.count
                    infoKeyValueRow(
                        title: "Tracker Learning",
                        value: environment.trackerBlockingService.isEnabled
                            ? "Enabled (Threshold: \(environment.trackerBlockingService.learnThreshold) sites, \(blockedTrackers) blocked / \(totalTrackers) learned)"
                            : "Disabled"
                    )
                    Divider()
                    infoKeyValueRow(
                        title: "Canvas Fingerprinting Protection",
                        value: environment.canvasFingerprintingService.isEnabled ? "Active (Protection Enabled)" : "Disabled"
                    )
                    Divider()
                    infoKeyValueRow(
                        title: "Custom Site Permissions",
                        value: "\(environment.websitePermissionService.sites.count) origin\(environment.websitePermissionService.sites.count == 1 ? "" : "s") configured"
                    )
                }
            }
        }
    }

    private var systemDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "System & Process Information")

            InternalPageRow {
                VStack(spacing: 8) {
                    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    infoKeyValueRow(title: "Illuminate Version", value: "\(appVersion) (\(appBuild))")
                    Divider()
                    infoKeyValueRow(title: "Operating System", value: ProcessInfo.processInfo.operatingSystemVersionString)
                    Divider()
                    infoKeyValueRow(title: "Processor Cores", value: "\(ProcessInfo.processInfo.processorCount) logical cores")
                    Divider()
                    let memoryString = ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory)
                    infoKeyValueRow(title: "Physical Memory", value: memoryString)
                    Divider()
                    infoKeyValueRow(title: "Process Identifier (PID)", value: "\(ProcessInfo.processInfo.processIdentifier)")
                    Divider()
                    infoKeyValueRow(title: "Process Uptime", value: formattedUptime(ProcessInfo.processInfo.systemUptime))
                }
            }
        }
    }


    private func infoKeyValueRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private func formattedUptime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "\(Int(seconds))s"
    }

    private func loadUserAgent() async {
        if let existing = environment.webKitManager.currentUserAgent {
            self.userAgent = existing
            return
        }
        let fetched = await environment.webKitManager.fetchUserAgent()
        self.userAgent = fetched
    }

    private func purgeCaches() {
        URLCache.shared.removeAllCachedResponses()
        cachePurged = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            cachePurged = false
        }
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func copyDiagnosticsToPasteboard() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let dict: [String: Any] = [
            "app": [
                "name": "Illuminate",
                "version": appVersion,
                "build": appBuild
            ],
            "system": [
                "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "processorCount": ProcessInfo.processInfo.processorCount,
                "physicalMemory": ProcessInfo.processInfo.physicalMemory,
                "pid": ProcessInfo.processInfo.processIdentifier,
                "uptimeSeconds": ProcessInfo.processInfo.systemUptime
            ],
            "profile": [
                "name": environment.profile.name,
                "id": environment.profile.id.uuidString,
                "isGuest": environment.isGuestSession,
                "sessionIdentifier": environment.sessionIdentifier?.uuidString ?? "none",
                "themeColor": tabManager.windowThemeColor.toHex() ?? "none",
                "userInterfaceStyle": tabManager.userInterfaceStyle.rawValue
            ],
            "webKit": [
                "userAgent": userAgent,
                "cookiesEnabled": environment.webKitManager.cookiesEnabled,
                "httpsOnlyEnabled": environment.webKitManager.httpsOnlyEnabled,
                "memoryCacheMB": URLCache.shared.memoryCapacity / 1024 / 1024,
                "diskCacheMB": URLCache.shared.diskCapacity / 1024 / 1024
            ],
            "tabs": [
                "count": tabManager.tabs.count,
                "activeTabID": tabManager.activeTabID?.uuidString ?? "none",
                "activeTabTitle": tabManager.activeTab?.title ?? "",
                "activeTabURL": tabManager.activeTab?.url?.absoluteString ?? "",
                "tabGroupsCount": tabManager.tabGroupManager.groups.count,
                "isFullScreen": tabManager.isFullScreen
            ],
            "protection": [
                "trackerBlockingEnabled": environment.trackerBlockingService.isEnabled,
                "trackerLearnThreshold": environment.trackerBlockingService.learnThreshold,
                "trackerDomainsCount": environment.trackerBlockingService.domainStats.count,
                "canvasFingerprintingEnabled": environment.canvasFingerprintingService.isEnabled,
                "configuredSitePermissionsCount": environment.websitePermissionService.sites.count
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: data, encoding: .utf8) {
            copyToPasteboard(jsonString)
        } else {
            copyToPasteboard("User Agent: \(userAgent)\nProfile: \(environment.profile.name)\nOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        }

        didCopyDiagnostics = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopyDiagnostics = false
        }
    }
}
