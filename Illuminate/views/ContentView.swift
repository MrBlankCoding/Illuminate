//
//  ContentView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var viewModel: ContentViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var findViewModel = FindViewModel()
    @StateObject private var zoomViewModel = ZoomViewModel()
    @State private var hoveredSidebarTabID: UUID?

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            backgroundLayer

            HStack(alignment: .top, spacing: 0) {
                if tabManager.showSidebar {
                    TabDisplayView(hoveredSidebarTabID: $hoveredSidebarTabID)
                        .frame(width: 220)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(2)
                }

                VStack(spacing: 0) {
                    TopBarView(
                        addressBarText: $viewModel.addressBarText,
                        onNavigate: viewModel.navigateToAddressBarURL
                    )
                    .zIndex(3)

                    browserContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(1)
                }
            }
            .overlayPreferenceValue(TabRowFramePreferenceKey.self) { preferences in
                GeometryReader { geometry in
                    if let hoveredID = hoveredSidebarTabID,
                       let anchor = preferences[hoveredID],
                       let tab = tabManager.tabs.first(where: { $0.id == hoveredID }) {
                        let rect = geometry[anchor]
                        
                        TabPeekPreview(image: tab.snapshot)
                            .position(x: rect.maxX + 126, y: rect.midY)
                            .id(hoveredID)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: hoveredID)
                            .onAppear {
                                if tab.id == tabManager.activeTabID {
                                    tab.refreshSnapshot()
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowConfigurator())
        .preferredColorScheme(tabManager.userInterfaceStyle.colorScheme)
        .onAppear {
            DispatchQueue.main.async {
                viewModel.updateAddressBarFromActiveTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findInPage)) { _ in
            findViewModel.setWebView(tabManager.activeTab?.webView)
            findViewModel.isPresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomChanged)) { notification in
            if let level = notification.userInfo?["level"] as? Double {
                zoomViewModel.updateZoom(level)
            }
        }
        .onChange(of: tabManager.activeTabID) { oldValue, newValue in
            findViewModel.setWebView(tabManager.activeTab?.webView)
            zoomViewModel.hide()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            theme.windowBase
                .ignoresSafeArea()

            if !tabManager.isResizing {
                if let imageURL = URL(string: tabManager.backgroundImageURL), !tabManager.backgroundImageURL.isEmpty {
                    CachedBackgroundImageView(url: imageURL)
                        .mask(
                            HStack(spacing: 0) {
                                let showInSidebar = tabManager.showBackgroundBehindSidebar
                                
                                Rectangle()
                                    .frame(width: tabManager.showSidebar ? 220 : 0)
                                    .opacity(showInSidebar ? 1.0 : 0.0)
                                Rectangle()
                            }
                        )
                        .ignoresSafeArea()
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabManager.showSidebar)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabManager.showBackgroundBehindSidebar)
                }

                Circle()
                    .fill(tabManager.windowThemeColor.opacity(0.14))
                    .frame(width: 420, height: 420)
                    .blur(radius: 90)
                    .offset(x: -220, y: -240)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.8), value: tabManager.windowThemeColor)
            } else {
                theme.itemHover.opacity(0.8)
                    .ignoresSafeArea()
            }
        }
    }


    @ViewBuilder
    private var browserContent: some View {
        ZStack(alignment: .top) {
            // Extended background/overlay
            ZStack {
                Group {
                    if tabManager.activeTab?.url == nil {
                        Color.clear
                    } else {
                        VisualEffectView(material: .contentBackground, blendingMode: .withinWindow)
                            .ignoresSafeArea()
                    }
                }
                
                Rectangle()
                    .strokeBorder(Color.borderSubtle, lineWidth: 1)
                    .padding(.top, -1)
                    .opacity(tabManager.activeTab?.url == nil ? 0.3 : 1.0)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ZStack {
                    if let activeTab = tabManager.activeTab {
                        WebView(tab: activeTab)
                            .id(activeTab.id)
                            .environmentObject(viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    if let activeTab = tabManager.activeTab, activeTab.lastNavigationHadNetworkError {
                        if activeTab.isDNSError {
                            SiteUnreachableView(host: activeTab.url?.host ?? "This site")
                                .padding(30)
                        } else {
                            NoInternetView(message: activeTab.lastNetworkErrorMessage ?? "Please check your connection and try again.")
                                .padding(30)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            if zoomViewModel.isPresented {
                VStack {
                    HStack {
                        Spacer()
                        ZoomIndicatorView(viewModel: zoomViewModel)
                            .padding(.top, 60)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }

            if findViewModel.isPresented {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FindInPageView(viewModel: findViewModel)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

}
