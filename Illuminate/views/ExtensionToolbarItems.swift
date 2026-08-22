//
//  ExtensionToolbarItems.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/21/26.
//

import SwiftUI
import WebKit

struct ExtensionToolbarItems: View {
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(profileEnvironment.extensionManager.installedExtensions.filter { profileEnvironment.extensionManager.isEnabled($0) }, id: \.self) { context in
                ExtensionToolbarItemView(context: context)
            }
        }
    }
}

struct ExtensionToolbarItemView: View {
    let context: WKWebExtensionContext
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @State private var isShowingPopup = false
    @State private var badgeText: String?
    @State private var icon: NSImage?
    @State private var isHovered = false

    var body: some View {
        Button {
            let action = context.action(for: tabManager.activeTab)
            if action?.presentsPopup == true {
                isShowingPopup.toggle()
            } else {
                // Fire action clicked event
                context.performAction(for: tabManager.activeTab)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                }
                
                if let badge = badgeText, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: 28, height: 28)
            .background(isHovered ? Color.secondary.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isShowingPopup, arrowEdge: .bottom) {
            if let action = context.action(for: tabManager.activeTab), let popupWebView = action.popupWebView {
                ExtensionPopupView(action: action, popupWebView: popupWebView)
            }
        }
        .onChange(of: isShowingPopup) { _, isShowing in
            if !isShowing {
                context.action(for: tabManager.activeTab)?.closePopup()
            }
        }
        .onAppear(perform: updateActionState)
        .onReceive(profileEnvironment.extensionManager.actionChanges) { updatedContext, updatedTab in
            if updatedContext === context && (updatedTab == nil || updatedTab === tabManager.activeTab) {
                updateActionState()
            }
        }
        .onChange(of: tabManager.activeTabID) { _, _ in
            updateActionState()
        }
        .help(context.webExtension.displayName ?? "")
    }
    
    private func updateActionState() {
        let action = context.action(for: tabManager.activeTab)
        self.icon = action?.icon(for: CGSize(width: 16, height: 16))
        self.badgeText = action?.badgeText
    }
}

struct ExtensionPopupView: View {
    let action: WKWebExtension.Action
    let popupWebView: WKWebView
    @State private var popupSize: CGSize = CGSize(width: 320, height: 400)
    
    var body: some View {
        ExtensionPopupWebViewRepresentable(popupWebView: popupWebView, preferredSize: $popupSize)
            .frame(width: popupSize.width, height: popupSize.height)
    }
}

struct ExtensionPopupWebViewRepresentable: NSViewRepresentable {
    let popupWebView: WKWebView
    @Binding var preferredSize: CGSize
    
    func makeNSView(context: Context) -> WKWebView {
        // popupWebView is already preloaded with the popup page by WKWebExtensionAction.
        return popupWebView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
