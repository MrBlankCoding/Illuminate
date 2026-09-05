//
//  PermissionsPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import SwiftUI

struct PermissionsPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(WebsitePermissionService.self) private var permissionService: WebsitePermissionService

    var body: some View {
        InternalPage(icon: "hand.raised.fill", title: "Permissions", accentColor: tabManager.windowThemeColor) {
            if permissionService.sites.isEmpty {
                InternalPageEmptyState(icon: "hand.raised", message: "No websites have requested permissions yet.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(permissionService.sites) { site in
                        InternalPageRow {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(site.origin).font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    Button("Reset") { permissionService.clearPermissions(for: site.origin) }
                                        .buttonStyle(InternalPageChipButtonStyle(color: .secondary))
                                }
                                ForEach(WebsitePermissionType.allCases) { type in
                                     HStack(spacing: MacDesign.Spacing.medium) {
                                        Image(systemName: type.icon).frame(width: 16)
                                        Text(type.title).font(.webCaption)
                                        Spacer()
                                        Picker(type.title, selection: binding(for: site.origin, type: type)) {
                                            Text("Ask").tag(WebsitePermissionDecision.prompt)
                                            Text("Allow").tag(WebsitePermissionDecision.allow)
                                            Text("Block").tag(WebsitePermissionDecision.deny)
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .frame(width: 210)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func binding(for origin: String, type: WebsitePermissionType) -> Binding<WebsitePermissionDecision> {
        Binding(
            get: { permissionService.decision(for: origin, type: type) },
            set: { permissionService.set($0, for: origin, type: type) }
        )
    }
}

struct WebsitePermissionPromptView: View {
    let request: PendingWebsitePermission
    let resolve: (WebsitePermissionDecision) -> Void

    var body: some View {
        VStack(spacing: MacDesign.Spacing.section) {
            Image(systemName: request.types.count == 1 ? request.types[0].icon : "hand.raised.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.tint)
            VStack(spacing: 7) {
                Text("\(request.origin) wants access")
                    .font(.system(size: 18, weight: .semibold))
                Text(request.types.map(\.title).joined(separator: " and "))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Don't Allow") { resolve(.deny) }
                Spacer()
                Button("Allow") { resolve(.allow) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(MacDesign.Spacing.page)
        .frame(width: 360)
    }
}
