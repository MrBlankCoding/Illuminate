//
//  PageInfoPopoverView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/19/26.
//

import SwiftUI

struct PageInfoPopoverView: View {
    let tab: Tab?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCookieManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(iconColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    
                    if let host = tab?.url?.host {
                        Text(host)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if let tab = tab, tab.url?.scheme != "illuminate" {
                    InfoRow(icon: "lock.shield", title: "Security", subtitle: securityDescription, color: iconColor)
                    
                    if tab.hasMixedContentWarning {
                        InfoRow(icon: "exclamationmark.triangle", title: "Mixed Content", subtitle: "Some parts of this page are not secure.", color: .orange)
                    }
                    
                    if tab.isDNSError {
                        InfoRow(icon: "network.slash", title: "DNS Failure", subtitle: tab.lastNetworkErrorMessage ?? "Could not resolve hostname.", color: .red)
                    } else if tab.lastNavigationHadNetworkError {
                        InfoRow(icon: "wifi.exclamationmark", title: "Network Error", subtitle: tab.lastNetworkErrorMessage ?? "Failed to load page.", color: .red)
                    }
                    
                    Button {
                        showingCookieManager = true
                    } label: {
                        HStack {
                            InfoRow(icon: "cookie", title: "Cookies", subtitle: "Manage site data", color: Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").opacity(0.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .hoverCursor(.pointingHand)
                    .popover(isPresented: $showingCookieManager, arrowEdge: .trailing) {
                        CookieManagerView(domain: tab.url?.host)
                            .frame(width: 350, height: 450)
                            .glassBackground()
                    }
                    
                    InfoRow(icon: "hand.raised.fill", title: "Permissions", subtitle: "No permissions requested", color: Color.textPrimary)
                    InfoRow(icon: "arrow.turn.up.forward.badge.magnifyingglass", title: "Redirects", subtitle: "Enhanced protection active", color: Color.textPrimary)
                } else {
                    InfoRow(icon: "info.circle", title: "System Page", subtitle: "This is an internal browser page.", color: Color.textPrimary)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
    
    private var isSecure: Bool {
        tab?.url?.scheme == "https"
    }
    
    private var iconName: String {
        if tab?.url?.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame {
            return "gearshape.fill"
        }
        if isSecure {
            return "lock.fill"
        }
        if tab?.url != nil {
            return "globe"
        }
        return "magnifyingglass"
    }
    
    private var iconColor: Color {
        if tab?.url?.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame {
            return .blue
        }
        if isSecure {
            return .green
        }
        return .orange
    }
    
    private var title: String {
        if tab?.url?.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame {
            return "Illuminate Settings"
        }
        if isSecure {
            return "Connection secure"
        }
        if tab?.url != nil {
            return "Connection not secure"
        }
        return "New Tab"
    }
    
    private var securityDescription: String {
        if isSecure {
            return "Your information is private."
        }
        return "You should not enter any sensitive information."
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
