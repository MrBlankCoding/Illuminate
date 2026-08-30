//
//  CookieManagerView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import SwiftUI
import WebKit
import Observation

struct CookieManagerView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(WebKitManager.self) private var webKitManager: WebKitManager
    @State private var viewModel: CookieViewModel

    init(domain: String? = nil) {
        _viewModel = State(initialValue: CookieViewModel(domain: domain))
    }

    var body: some View {
        let groupedCookies = viewModel.groupedCookies
        let sortedDomains = groupedCookies.keys.sorted()

        VStack(spacing: 0) {
            header
            searchBar
            
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if groupedCookies.isEmpty {
                emptyState
            } else {
                cookieList(groupedCookies: groupedCookies, sortedDomains: sortedDomains)
            }
        }
        .onAppear {
            viewModel.fetchCookies(with: webKitManager)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "shield.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tabManager.windowThemeColor)
            
            Text(viewModel.currentDomain ?? "Cookies")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
            TextField("Search cookies...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .frame(height: MacDesign.Size.urlBarHeight)
        .insetPanel(cornerRadius: MacDesign.Radius.control)
        .padding(.horizontal, MacDesign.Spacing.page)
        .padding(.bottom, MacDesign.Spacing.roomy)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48))
                .foregroundStyle(tabManager.windowThemeColor.opacity(0.4))
            Text(viewModel.searchText.isEmpty ? "No cookies found" : "No matching cookies")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func cookieList(
        groupedCookies: [String: [HTTPCookie]],
        sortedDomains: [String]
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(sortedDomains, id: \.self) { domain in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(domain)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            
                            Spacer()
                            
                            Button {
                                viewModel.deleteCookies(for: domain, with: webKitManager)
                            } label: {
                                SettingsShared.actionCapsule(icon: "trash", title: "Clear", tint: .red.opacity(0.72))
                            }
                            .buttonStyle(.plain)
                            .hoverCursor(.pointingHand)
                            .accessibilityLabel("Clear cookies for \(domain)")
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 1) {
                            ForEach(groupedCookies[domain] ?? [], id: \.self) { cookie in
                                cookieRow(cookie)
                            }
                        }
                        .insetPanel(cornerRadius: MacDesign.Radius.medium)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func cookieRow(_ cookie: HTTPCookie) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cookie.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(cookie.value)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                viewModel.deleteCookie(cookie, with: webKitManager)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary.opacity(0.5))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .accessibilityLabel("Delete cookie")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
