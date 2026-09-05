//
//  ContentView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    @Environment(ContentViewModel.self) private var viewModel: ContentViewModel
    @Environment(WebsitePermissionService.self) private var permissionService: WebsitePermissionService
    @Environment(\.colorScheme) private var colorScheme
    @State private var findViewModel = FindViewModel()
    @State private var zoomViewModel = ZoomViewModel()
    @State private var popupCoordinator = ExtensionPopupCoordinator()

    var body: some View {
        @Bindable var permissionService = permissionService
        GeometryReader { windowGeo in
        ZStack {
            BackgroundLayer(
                backgroundImageURL: tabManager.backgroundImageURL,
                windowThemeColor: tabManager.windowThemeColor,
                colorScheme: colorScheme
            )

            VStack(spacing: 0) {

                BrowserToolbarView(
                    onNavigate: viewModel.navigateToAddressBarURL
                )
                .zIndex(3)

                BrowserContentView(
                    tabs: tabManager.tabs,
                    activeTabID: tabManager.activeTabID,
                    windowThemeColor: tabManager.windowThemeColor,
                    colorScheme: colorScheme,
                    findViewModel: findViewModel,
                    zoomViewModel: zoomViewModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if let payload = popupCoordinator.activePopup {
                        ExtensionPopupPanel(
                            payload: payload,
                            windowWidth: windowGeo.size.width
                        )
                        .environment(tabManager)
                        .environment(environment)
                        .environment(popupCoordinator)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }
                }
                .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)

            if let request = environment.extensionManager.activePermissionRequest {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                PermissionRequestView(request: request)
                    .zIndex(10)
            }
        }
        .coordinateSpace(name: "browserWindow")
        } 
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowConfigurator())
        .preferredColorScheme(tabManager.userInterfaceStyle.colorScheme)
        .environment(popupCoordinator)
        .onAppear {
            DispatchQueue.main.async {
                AppFileOpening.shared.drain(into: tabManager)
            }
        }
        .onChange(of: AppFileOpening.shared.pendingURLs) { _, _ in
            AppFileOpening.shared.drain(into: tabManager)
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
            popupCoordinator.close()
        }
        .sheet(item: $permissionService.pendingRequest) { request in
            WebsitePermissionPromptView(request: request) { decision in
                permissionService.resolvePendingRequest(as: decision)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url, url.isFileURL {
                        DispatchQueue.main.async {
                            FinderReveal.open(url)
                        }
                    }
                }
            }
            return true
        }
    }
}

struct BackgroundLayer: View {
    let backgroundImageURL: String
    let windowThemeColor: Color
    let colorScheme: ColorScheme

    private var theme: BrowserTheme {
        BrowserTheme(accent: windowThemeColor, colorScheme: colorScheme, windowThemeColor: windowThemeColor)
    }

    var body: some View {
        theme.windowBase
            .ignoresSafeArea()
    }
}

struct BrowserContentView: View {
    let tabs: [Tab]
    let activeTabID: UUID?
    let windowThemeColor: Color
    let colorScheme: ColorScheme
    var findViewModel: FindViewModel
    var zoomViewModel: ZoomViewModel
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ContentViewModel.self) private var viewModel: ContentViewModel

    private var activeTab: Tab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    private var tabsWithActiveFirst: [Tab] {
        guard let activeTab else { return tabs }
        return [activeTab] + tabs.filter { $0.id != activeTab.id }
    }

    private var theme: BrowserTheme {
        BrowserTheme(accent: windowThemeColor, colorScheme: colorScheme, windowThemeColor: windowThemeColor)
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
                    .strokeBorder(Color.borderSubtle, lineWidth: MacDesign.Spacing.hairline)
                    .padding(.top, -1)
                    .opacity(activeTab?.url == nil ? 0.3 : 1.0)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ZStack {
                    ForEach(tabsWithActiveFirst) { tab in
                        let isActive = tab.id == activeTabID

                        WebView(tab: tab)
                            .transaction { $0.animation = nil }
                            .environment(viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(isActive ? 1 : 0)
                            .allowsHitTesting(isActive)
                            .accessibilityHidden(!isActive)
                            .zIndex(isActive ? 1 : 0)
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
                            .padding(.top, MacDesign.Spacing.regular)
                            .padding(.trailing, MacDesign.Spacing.roomy)
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
                            .padding(.trailing, MacDesign.Spacing.roomy)
                            .padding(.bottom, MacDesign.Spacing.roomy)
                    }
                }
            }
        }
    }
}
