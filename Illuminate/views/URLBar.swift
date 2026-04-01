//
//  URLBar.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Combine
import SwiftUI
import AppKit

struct URLBar: View {
    let activeTab: Tab?
    @Binding var addressText: String
    let themeColor: Color
    let onNavigate: () -> Void

    @EnvironmentObject private var urlSynchronizer: URLSynchronizer
    @FocusState private var isFocused: Bool
    @State private var didCopyURL = false
    @State private var isCopyHovered = false
    @State private var showingCookieManager = false
    @State private var isCookieHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isFocused ? themeColor : Color.textSecondary)

            TextField("Search or enter URL", text: $addressText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .focused($isFocused)
                .onSubmit {
                    onNavigate()
                }

            HStack(spacing: 6) {
                if !addressText.isEmpty {
                    Button {
                        copyAddressToPasteboard()
                    } label: {
                        Image(systemName: didCopyURL ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(didCopyURL ? Color.green : Color.textSecondary)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(isCopyHovered ? themeColor.opacity(0.16) : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(isCopyHovered ? Color.borderGlass : Color.clear, lineWidth: 1)
                            )
                            .scaleEffect(isCopyHovered ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.14), value: isCopyHovered)
                            .animation(.easeInOut(duration: 0.14), value: didCopyURL)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isCopyHovered = hovering
                    }
                    .hoverCursor(.pointingHand)
                    .help(didCopyURL ? "Copied" : "Copy URL")

                    Button {
                        showingCookieManager.toggle()
                    } label: {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(showingCookieManager ? Color.white : themeColor)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(showingCookieManager ? themeColor : (isCookieHovered ? themeColor.opacity(0.18) : Color.clear))
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(isCookieHovered || showingCookieManager ? themeColor.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isCookieHovered = hovering
                    }
                    .hoverCursor(.pointingHand)
                    .help("Manage Cookies")
                    .popover(isPresented: $showingCookieManager, arrowEdge: .bottom) {
                        CookieManagerView(domain: activeTab?.url?.host)
                            .frame(width: 350, height: 450)
                            .glassBackground()
                    }
                } else {
                    Color.clear
                        .frame(width: 46, height: 20)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.bgSurface.opacity(0.35),
                            Color.bgSurface.opacity(0.05),
                            Color.bgSurface.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderGlass, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 10,
            y: 4
        )
        .focusRing(isFocused)
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
        .hoverCursor(.iBeam)
        .onAppear {
            if addressText.isEmpty {
                addressText = activeTab?.url?.absoluteString ?? urlSynchronizer.currentURL?.absoluteString ?? ""
            }
        }
        .onReceive(urlSynchronizer.$currentURL) { newURL in
            guard !isFocused else { return }
            addressText = newURL?.absoluteString ?? ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusURLBar)) { _ in
            isFocused = true
        }
    }

    private var statusIcon: String {
        if activeTab?.url?.scheme == "https" {
            return "lock.fill"
        }
        return "magnifyingglass"
    }

    private func copyAddressToPasteboard() {
        let value = activeTab?.url?.absoluteString ?? addressText
        guard !value.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        didCopyURL = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            didCopyURL = false
        }
    }
}
