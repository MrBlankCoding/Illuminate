//
//  MoreOptionsMenu.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct MoreOptionsMenu: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var profileEnvironment: ProfileEnvironment
    @State private var isHovered = false

    var body: some View {
        Menu {
            Group {
                Button {
                    NotificationCenter.default.post(name: .findInPage, object: nil)
                } label: {
                    Label("Find in Page", systemImage: "magnifyingglass")
                }

                Divider()

                Button {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                } label: {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }

                Button {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                } label: {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }

                Button {
                    NotificationCenter.default.post(name: .resetZoom, object: nil)
                } label: {
                    Label("Reset Zoom", systemImage: "1.magnifyingglass")
                }

                Divider()

                Button {
                    NotificationCenter.default.post(name: .openDevTools, object: nil)
                } label: {
                    Label("Developer Tools", systemImage: "hammer.fill")
                }
            }

            Divider()

            Group {
                Button {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                } label: {
                    Label("New Tab", systemImage: "plus.square")
                }

                Button {
                    DockMenuWindowRouter.shared.openProfile?(profileEnvironment.profile.id)
                } label: {
                    Label("New Window", systemImage: "macwindow.badge.plus")
                }
            }

            Divider()

            Group {
                Button {
                    guard let webView = tabManager.activeTab?.webView else { return }
                    let printInfo = NSPrintInfo.shared
                    let operation = NSPrintOperation(view: webView)
                    operation.printInfo = printInfo
                    operation.showsPrintPanel = true
                    operation.showsProgressPanel = true
                    operation.run()
                } label: {
                    Label("Print Page", systemImage: "printer")
                }
                .disabled(tabManager.activeTab?.webView == nil)
            }

            Divider()

            Group {
                Button {
                    openInternalPage(.history)
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    openInternalPage(.extensions)
                } label: {
                    Label("Extensions", systemImage: "puzzlepiece.fill")
                }

                Button {
                    openInternalPage(.passwords)
                } label: {
                    Label("Passwords", systemImage: "key.fill")
                }

                Button {
                    openInternalPage(.protection)
                } label: {
                    Label("Privacy & Protection", systemImage: "shield.fill")
                }

                Button {
                    openInternalPage(.permissions)
                } label: {
                    Label("Permissions", systemImage: "hand.raised.fill")
                }

                Button {
                    openInternalPage(.downloads)
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovered ? Color.textPrimary : Color.textSecondary)
                .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
                .macControlBackground(isHovered: isHovered, tint: tabManager.windowThemeColor, radius: MacDesign.Radius.full)
                .contentShape(Circle())
                .animation(MacDesign.fastAnimation, value: isHovered)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { isHovered = $0 }
        .hoverCursor(.pointingHand)
        .help("More Options")
        .accessibilityLabel("More Options")
        .accessibilityIdentifier("browser.toolbar.moreOptionsButton")
    }

    private func openInternalPage(_ page: IlluminatePage) {
        if let activeTab = tabManager.activeTab {
            activeTab.load(url: page.url)
        } else {
            tabManager.createTab(url: page.url)
        }
    }
}
