//
//  ProtectionPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

// illuminate://protection

struct ProtectionPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @Environment(WebKitManager.self) private var webKitManager: WebKitManager
    @Environment(TrackerBlockingService.self) private var trackerBlockingService: TrackerBlockingService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        InternalPage(
            icon: "shield.fill",
            title: "Privacy & Protection",
            accentColor: tabManager.windowThemeColor
        ) {
            VStack(alignment: .leading, spacing: 24) {
                httpsSection
                trackerBlockingSection
                PrivacySettingsView(isEmbedded: true)
            }
        }
    }

    private var httpsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "Security")
            InternalPageRow {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HTTPS-only mode")
                            .font(.system(size: 14, weight: .medium))
                        Text("Block requests to sites that dont support HTTPS.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { webKitManager.httpsOnlyEnabled }, set: { webKitManager.httpsOnlyEnabled = $0 }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("HTTPS-only mode")
                        .accessibilityIdentifier("browser.protection.httpsOnlyToggle")
                    }
                }
            }
        }

        private var trackerBlockingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InternalPageSectionHeader(title: "Tracker Blocking")

            InternalPageRow {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable tracker learning")
                            .font(.system(size: 14, weight: .medium))
                        Text("Look for common trackers across sites, and then once found blocks the domain")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { trackerBlockingService.isEnabled }, set: { trackerBlockingService.isEnabled = $0 }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Enable tracker learning")
                        .accessibilityIdentifier("browser.protection.trackerLearningToggle")
                    }
                }

                if trackerBlockingService.isEnabled {
                InternalPageRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Block after")
                                .font(.system(size: 14, weight: .medium))
                            Text("Number of sites a tracker must be caught on")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Stepper(
                            "\(trackerBlockingService.learnThreshold) site\(trackerBlockingService.learnThreshold == 1 ? "" : "s")",
                            value: Binding(get: { trackerBlockingService.learnThreshold }, set: { trackerBlockingService.learnThreshold = $0 }),
                            in: 1...10
                        )
                        .fixedSize()
                        .accessibilityIdentifier("browser.protection.learnThresholdStepper")
                    }
                }

                InternalPageRow {
                    HStack(spacing: 12) {
                        let blocked = trackerBlockingService.domainStats.filter(\.isBlocked).count
                        let seen    = trackerBlockingService.domainStats.count
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Learned trackers")
                                .font(.system(size: 14, weight: .medium))
                            Text("\(blocked) blocked · \(seen) seen")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            trackerBlockingService.clearLearnedData()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(InternalPageChipButtonStyle(color: .red))
                        .disabled(trackerBlockingService.domainStats.isEmpty)
                    }
                }

                if !trackerBlockingService.domainStats.isEmpty {
                    TrackerDomainListView(service: trackerBlockingService)
                }
            }
        }
    }

}

private struct TrackerDomainListView: View {
    let service: TrackerBlockingService
    @State private var isExpanded = false

    var body: some View {
        InternalPageRow {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(spacing: 0) {
                        ForEach(service.domainStats) { stat in
                            TrackerDomainRow(stat: stat, service: service)
                if stat.id != service.domainStats.last?.id {
                    CappedDivider().padding(.leading, MacDesign.Spacing.section)
                            }
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    Text("Learned domains (\(service.domainStats.count))")
                        .font(.system(size: 14, weight: .medium))
                }
            )
        }
    }
}

private struct TrackerDomainRow: View {
    let stat: DomainStat
    let service: TrackerBlockingService

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .help(statusHelp)

            VStack(alignment: .leading, spacing: 1) {
                Text(stat.domain)
                    .font(.webCaption)
                    .lineLimit(1)
                Text("\(stat.firstPartyCount) site\(stat.firstPartyCount == 1 ? "" : "s")")
                    .font(.webSmallRegular)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button {
                    service.clearOverride(for: stat.domain)
                } label: {
                    Label("Auto (heuristic)", systemImage: "wand.and.stars")
                }
                .disabled(stat.override == nil)

                Divider()

                Button {
                    service.allow(domain: stat.domain)
                } label: {
                    Label("Always allow", systemImage: "checkmark.shield")
                }
                .disabled(stat.override == .allowed)

                Button {
                    service.block(domain: stat.domain)
                } label: {
                    Label("Always block", systemImage: "xmark.shield")
                }
                .disabled(stat.override == .blocked)
            } label: {
                Image(systemName: overrideIcon)
                    .font(.webCaption)
                    .foregroundStyle(.secondary)
                    .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Override blocking decision for \(stat.domain)")
        }
        .padding(.vertical, MacDesign.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stat.domain), seen on \(stat.firstPartyCount) sites, \(statusHelp)")
    }

    private var statusColor: Color {
        switch stat.override {
        case .allowed: return .green
        case .blocked: return .red
        case .none:    return stat.isBlocked ? .orange : .secondary
        }
    }

    private var statusHelp: String {
        switch stat.override {
        case .allowed: return "Manually allowed"
        case .blocked: return "Manually blocked"
        case .none:    return stat.isBlocked ? "Auto-blocked" : "Observed, not yet blocked"
        }
    }

    private var overrideIcon: String {
        switch stat.override {
        case .allowed: return "checkmark.shield.fill"
        case .blocked: return "xmark.shield.fill"
        case .none:    return "shield"
        }
    }
}
