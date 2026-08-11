//
//  MoreOptionsMenu.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI

struct MoreOptionsMenu: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var profileEnvironment: ProfileEnvironment

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

                Button {
                    guard let window = NSApp.keyWindow,
                          let contentView = window.contentView else { return }
                    let bounds = contentView.bounds
                    guard let imageRep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
                    contentView.cacheDisplay(in: bounds, to: imageRep)
                    guard let pngData = imageRep.representation(using: .png, properties: [:]) else { return }

                    let savePanel = NSSavePanel()
                    savePanel.allowedFileTypes = ["png"]
                    savePanel.nameFieldStringValue = "screenshot.png"
                    savePanel.begin { response in
                        guard response == .OK, let url = savePanel.url else { return }
                        try? pngData.write(to: url)
                    }
                } label: {
                    Label("Capture Screenshot", systemImage: "camera")
                }
            }

            Divider()

            Group {
                Button {
                    openInternalPage("illuminate://history")
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    openInternalPage("illuminate://passwords")
                } label: {
                    Label("Passwords", systemImage: "key.fill")
                }

                Button {
                    openInternalPage("illuminate://protection")
                } label: {
                    Label("Privacy & Protection", systemImage: "shield.fill")
                }

                Button {
                    openInternalPage("illuminate://permissions")
                } label: {
                    Label("Permissions", systemImage: "hand.raised.fill")
                }

                Button {
                    openInternalPage("illuminate://cookies")
                } label: {
                    Label("Cookies", systemImage: "circle.hexagongrid.fill")
                }

                Button {
                    openInternalPage("illuminate://downloads")
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("More Options")
    }

    private func openInternalPage(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        if let activeTab = tabManager.activeTab {
            activeTab.load(url: url)
        } else {
            tabManager.createTab(url: url)
        }
    }
}
