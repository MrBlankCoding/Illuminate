//
//  SidebarTabRow.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import SwiftUI

struct SidebarTabRow: View {
    @ObservedObject var tab: Tab
    let themeColor: Color
    let isActive: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCopyLink: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(isActive ? themeColor : Color.clear)
                    .frame(width: 4, height: 20)

                faviconPlate

                VStack(alignment: .leading, spacing: 0) {
                    Text(tab.title.isEmpty ? "New Tab" : tab.title)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if tab.isHibernated {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(themeColor.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(themeColor.opacity(0.12))
                        .clipShape(Circle())
                } else {
                    Color.clear.frame(width: 22, height: 22)
                }

                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.bgElevated : (tab.groupID != nil ? Color.primary.opacity(0.12) : (isHovered ? themeColor.opacity(0.15) : Color.clear)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                onSelect()
            }
            
            if isHovered || isActive {
                closeButton(for: tab)
                    .padding(.trailing, 8)
                    .transition(.opacity)
            }
            
            // Loading Bar
            if tab.isLoading && tab.estimatedProgress < 1.0 {
                VStack {
                    Spacer()
                    ProgressView(value: tab.estimatedProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(themeColor)
                        .scaleEffect(x: 1, y: 0.5, anchor: .bottom)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 2)
                }
                .transition(.opacity)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.borderGlass : (isHovered ? Color.borderGlass.opacity(0.6) : Color.clear), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .contextMenu {
            Button("Copy Link") {
                onCopyLink()
            }
            .disabled(tab.url == nil)

            Button("Bookmark Tab") {
                onBookmark()
            }
            .disabled(tab.url == nil)
            
            Divider()
            
            Button("Close Tab", role: .destructive) {
                onClose()
            }
        }
    }

    private var faviconPlate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? themeColor.opacity(0.16) : Color.white.opacity(0.05))
                .frame(width: 24, height: 24)

            favicon(for: tab, isActive: isActive)
        }
    }

    private func favicon(for tab: Tab, isActive: Bool) -> some View {
        Group {
            if let favicon = tab.favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isActive ? themeColor : Color.textSecondary)
            }
        }
        .frame(width: 18, height: 18)
    }

    private func closeButton(for tab: Tab) -> some View {
        Button {
            onClose()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 20, height: 20)
                
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Color.textSecondary)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
