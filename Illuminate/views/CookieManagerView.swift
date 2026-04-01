//
//  CookieManagerView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import SwiftUI
import WebKit

struct CookieManagerView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var webKitManager: WebKitManager
    @StateObject private var viewModel: CookieViewModel

    init(domain: String? = nil) {
        _viewModel = StateObject(wrappedValue: CookieViewModel(domain: domain))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if viewModel.filteredCookies.isEmpty {
                emptyState
            } else {
                cookieList
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
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
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

    private var cookieList: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(viewModel.sortedDomains, id: \.self) { domain in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(domain)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            
                            Spacer()
                            
                            Button {
                                viewModel.deleteCookies(for: domain, with: webKitManager)
                            } label: {
                                Text("Clear")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.red.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .hoverCursor(.pointingHand)
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 1) {
                            ForEach(viewModel.groupedCookies[domain] ?? [], id: \.self) { cookie in
                                cookieRow(cookie)
                            }
                        }
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
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
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
