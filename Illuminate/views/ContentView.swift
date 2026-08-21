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
    @EnvironmentObject private var environment: ProfileEnvironment
    @EnvironmentObject private var viewModel: ContentViewModel
    @EnvironmentObject private var permissionService: WebsitePermissionService
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var findViewModel = FindViewModel()
    @StateObject private var zoomViewModel = ZoomViewModel()

    var body: some View {
        ZStack {
            BackgroundLayer(
                isResizing: tabManager.isResizing,
                backgroundImageURL: tabManager.backgroundImageURL,
                windowThemeColor: tabManager.windowThemeColor,
                colorScheme: colorScheme
            )
            
            VStack(spacing: 0) {
                if environment.isGuestSession {
                    PrivateBrowsingBanner()
                        .zIndex(4)
                }

                BrowserToolbarView(
                    addressBarText: $viewModel.addressBarText,
                    onNavigate: viewModel.navigateToAddressBarURL
                )
                .zIndex(3)

                BrowserContentView(
                    activeTab: tabManager.activeTab,
                    windowThemeColor: tabManager.windowThemeColor,
                    colorScheme: colorScheme,
                    findViewModel: findViewModel,
                    zoomViewModel: zoomViewModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1)
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
        .onChange(of: tabManager.activeTabID) { _, _ in
            findViewModel.setWebView(tabManager.activeTab?.webView)
            zoomViewModel.hide()
        }
        .sheet(item: $permissionService.pendingRequest) { request in
            WebsitePermissionPromptView(request: request) { decision in
                permissionService.resolvePendingRequest(as: decision)
            }
        }
    }
}

struct BackgroundLayer: View {
    let isResizing: Bool
    let backgroundImageURL: String
    let windowThemeColor: Color
    let colorScheme: ColorScheme
    
    private var theme: BrowserTheme {
        BrowserTheme(accent: windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.windowBase
                .ignoresSafeArea()

            if !isResizing,
               !backgroundImageURL.isEmpty,
               let imageURL = URL(string: backgroundImageURL) {
                CachedBackgroundImageView(url: imageURL)
                    .ignoresSafeArea()
            } else {
                DefaultBackgroundView()
            }
        }
    }
}

struct DefaultBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            Image("DefaultBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .ignoresSafeArea()
        }
    }
}

struct BrowserContentView: View {
    let activeTab: Tab?
    let windowThemeColor: Color
    let colorScheme: ColorScheme
    @ObservedObject var findViewModel: FindViewModel
    @ObservedObject var zoomViewModel: ZoomViewModel
    @EnvironmentObject private var viewModel: ContentViewModel

    private var theme: BrowserTheme {
        BrowserTheme(accent: windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Group {
                    if activeTab?.url == nil {
                        Color.clear
                    } else {
                        Rectangle()
                            .fill(.regularMaterial)
                            .ignoresSafeArea()
                    }
                }

                Rectangle()
                    .strokeBorder(theme.separator, lineWidth: 1)
                    .padding(.top, -1)
                    .opacity(activeTab?.url == nil ? 0.3 : 1.0)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ZStack {
                    if let activeTab = activeTab {
                        WebView(tab: activeTab)
                            .id(activeTab.id)
                            .environmentObject(viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if let activeTab = activeTab,
                       let error = activeTab.networkError {
                        BrowserErrorPageView(error: error)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity.animation(MacDesign.fastAnimation))
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            
            if zoomViewModel.isPresented {
                VStack {
                    HStack {
                        Spacer()
                        ZoomIndicatorView(viewModel: zoomViewModel)
                            .padding(.top, 12)
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
                        FindInPageView(viewModel: findViewModel, theme: theme)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
    }
}
