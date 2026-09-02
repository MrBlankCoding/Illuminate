//
//  NewTabView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftData
import SwiftUI

struct NewTabView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment

    @Environment(\.colorScheme) private var colorScheme
    @State private var isCustomizePanelShown = false
    @State private var isShelfVisible = false
    @State private var shelfTab: ShelfTab = .easels
    @State private var hasAppeared = false

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    var body: some View {
        HStack(spacing: 0) {
            if isShelfVisible {
                NewTabShelfSidebar(selectedTab: $shelfTab, isVisible: $isShelfVisible)
                    .frame(width: MacDesign.Size.sidePanelWidth)
                    .background(.ultraThinMaterial)
                    .overlay(Rectangle().fill(Color.primary.opacity(0.06)).frame(width: MacDesign.Spacing.hairlineThin), alignment: .trailing)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: MacDesign.Size.toolbarRowHeight) {
                        Spacer(minLength: MacDesign.Spacing.largeSpacer)
                        header
                        NewTabBookmarkGrid()
                        Spacer(minLength: MacDesign.Spacing.largeSpacer)
                    }
                    .frame(maxWidth: .infinity, minHeight: 480)
                    .padding(.horizontal, MacDesign.Spacing.pageHeaderPadding)
                }
                .scrollIndicators(.hidden)

                HStack {
                    customizeButton
                        .padding(.trailing, MacDesign.Spacing.section)
                }
                .padding(.bottom, MacDesign.Spacing.section)
            }
            .overlay(alignment: .bottomLeading) {
                shelfToggleButton
                    .padding(.leading, MacDesign.Spacing.section)
                    .padding(.bottom, MacDesign.Spacing.section)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isCustomizePanelShown {
                NewTabCustomizePanel()
                    .environment(tabManager)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
        .ignoresSafeArea()
        .preferredColorScheme(tabManager.userInterfaceStyle.colorScheme)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    private var header: some View {
        VStack(spacing: MacDesign.Spacing.control) {
            Text("Illuminate")
                .font(.webHero)
                .tracking(1)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.32), radius: MacDesign.Spacing.medium, y: MacDesign.Spacing.micro)
                .shadow(color: .black.opacity(0.18), radius: MacDesign.Spacing.micro, y: MacDesign.Spacing.hairline)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : MacDesign.Spacing.tight)
    }

    private var shelfToggleButton: some View {
        Button {
            withAnimation(MacDesign.springAnimation) {
                isShelfVisible.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.webCaptionBold)
                .frame(width: MacDesign.Size.floatingButton, height: MacDesign.Size.floatingButton)
                .background(AnyShapeStyle(.ultraThinMaterial), in: Circle())
                .foregroundStyle(.white.opacity(0.9))
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: MacDesign.Spacing.hairlineThin)
                }
                .shadow(color: .black.opacity(0.25), radius: MacDesign.Spacing.mini, y: MacDesign.Spacing.micro)
                .contentShape(Circle())
                .padding(MacDesign.Spacing.small)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShelfVisible ? "Hide shelf sidebar" : "Show shelf sidebar")
        .accessibilityIdentifier("browser.newTab.shelfToggleButton")
        .accessibilityHint(isShelfVisible ? "Hides the shelf sidebar" : "Shows the shelf sidebar")
        .help(isShelfVisible ? "Hide Shelf" : "Show Shelf")
    }

    private var customizeButton: some View {
        Button {
            withAnimation(MacDesign.springAnimation) {
                isCustomizePanelShown.toggle()
            }
        } label: {
            Image(systemName: isCustomizePanelShown ? "xmark" : "pencil")
                .font(.webCaptionBold)
                .frame(width: MacDesign.Size.floatingButton, height: MacDesign.Size.floatingButton)
                .background(
                    isCustomizePanelShown
                        ? AnyShapeStyle(tabManager.windowThemeColor.opacity(0.85))
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
                .foregroundStyle(isCustomizePanelShown ? .white : .white.opacity(0.9))
                .overlay {
                    Circle()
                        .stroke(
                            isCustomizePanelShown
                                ? tabManager.windowThemeColor
                                : Color.white.opacity(0.18),
                            lineWidth: MacDesign.Spacing.hairlineThin
                        )
                }
                .shadow(
                    color: isCustomizePanelShown
                        ? tabManager.windowThemeColor.opacity(0.35)
                        : .black.opacity(0.25),
                    radius: isCustomizePanelShown ? MacDesign.Spacing.control : MacDesign.Spacing.mini,
                    y: MacDesign.Spacing.micro
                )
                .contentShape(Circle())
                .padding(MacDesign.Spacing.small)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCustomizePanelShown ? "Close customize panel" : "Customize new tab page")
        .accessibilityIdentifier("browser.newTab.customizeButton")
        .accessibilityHint(isCustomizePanelShown ? "Closes the customize panel" : "Opens the customize panel")
        .help(isCustomizePanelShown ? "Close" : "Customize")
    }

    private var backgroundView: some View {
        ZStack {
            if let backgroundImageURL {
                CachedBackgroundImageView(url: backgroundImageURL)
            } else {
                GeometryReader { geo in
                    Image("Background Image")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var backgroundImageURL: URL? {
        guard !tabManager.backgroundImageURL.isEmpty else { return nil }
        return URL(string: tabManager.backgroundImageURL)
    }
}
