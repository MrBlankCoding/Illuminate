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
    @StateObject private var findViewModel = FindViewModel()
    @StateObject private var zoomViewModel = ZoomViewModel()

    var body: some View {
        ZStack {
            backgroundLayer

            HStack(alignment: .top, spacing: 0) {
                if tabManager.showSidebar {
                    TabDisplayView()
                        .frame(width: 240)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                browserContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlayPreferenceValue(TabRowFramePreferenceKey.self) { preferences in
                GeometryReader { geometry in
                    if let hoveredID = tabManager.hoveredSidebarTabID,
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
                if tabManager.tabs.isEmpty {
                    viewModel.createNewTab()
                } else {
                    viewModel.updateAddressBarFromActiveTab()
                }
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
            Color.bgBase
                .ignoresSafeArea()

            if !tabManager.isResizing {
                if let imageURL = URL(string: tabManager.backgroundImageURL), !tabManager.backgroundImageURL.isEmpty {
                    GeometryReader { geo in
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                        }
                        .mask(
                            HStack(spacing: 0) {
                                let isNewTabPage = tabManager.activeTab?.url == nil
                                let showInSidebar = isNewTabPage && tabManager.showBackgroundBehindSidebar
                                
                                Rectangle()
                                    .frame(width: tabManager.showSidebar ? 240 : 0)
                                    .opacity(showInSidebar ? 1.0 : 0.0)
                                Rectangle()
                            }
                        )
                    }
                    .ignoresSafeArea()
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabManager.showSidebar)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabManager.showBackgroundBehindSidebar)
                }

                EllipticalGradient(
                    gradient: Gradient(colors: [
                        tabManager.windowThemeColor.opacity(0.18),
                        tabManager.windowThemeColor.opacity(0.05),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.85
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: tabManager.windowThemeColor)

                EllipticalGradient(
                    gradient: Gradient(colors: [
                        tabManager.windowThemeColor.opacity(0.12),
                        Color.clear
                    ]),
                    center: .bottomTrailing,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.6
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: tabManager.windowThemeColor)
            } else {
                tabManager.windowThemeColor.opacity(0.05)
                    .ignoresSafeArea()
            }
        }
    }


    @ViewBuilder
    private var browserContent: some View {
        ZStack(alignment: .top) {
            // Extended background/overlay
            ZStack {
                tabManager.activeTab?.url == nil ? AnyView(Color.clear) : AnyView(VisualEffectView(material: .contentBackground, blendingMode: .withinWindow).ignoresSafeArea())
                
                Rectangle()
                    .strokeBorder(Color.borderGlass, lineWidth: 1)
                    .padding(.top, -1)
                    .opacity(tabManager.activeTab?.url == nil ? 0.3 : 1.0)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if let activeTab = tabManager.activeTab {
                    WebView(tab: activeTab)
                        .environmentObject(viewModel)
                        .id(activeTab.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                    if activeTab.lastNavigationHadNetworkError {
                        if activeTab.isDNSError {
                            SiteUnreachableView(host: activeTab.url?.host ?? "This site")
                                .padding(30)
                        } else {
                            NoInternetView(message: activeTab.lastNetworkErrorMessage ?? "Please check your connection and try again.")
                                .padding(30)
                        }
                    }
                } else {
                    PlaceholderView()
                }

                StatusBar(tab: tabManager.activeTab)
                    .padding(.bottom, 0)
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

#Preview {
    ContentView()
        .environmentObject(TabManager())
        .modelContainer(for: [Bookmark.self], inMemory: true)
}
