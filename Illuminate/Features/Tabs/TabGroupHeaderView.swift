//
//  TabGroupHeaderView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/11/26.
//

import SwiftUI

    private enum GroupHeaderMetrics {
        static let height: CGFloat = 22
        static let cornerRadius: CGFloat = MacDesign.Radius.groupHeader
        static let dotSize: CGFloat = 8
        static let horizontalPadding: CGFloat = MacDesign.Spacing.small
        static let verticalPadding: CGFloat = MacDesign.Spacing.micro
        static let nameFontSize: CGFloat = 11
        static let countFontSize: CGFloat = 10
    }

struct TabGroupHeaderView: View {
    var group: TabGroup
    let onToggleCollapse: () -> Void
    let onRename: (String) -> Void
    let onChangeColor: (TabGroupColor) -> Void
    let onCloseGroup: () -> Void
    let onDeleteGroup: () -> Void
    let onUngroupTabs: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isEditing = false

    private var groupColor: Color { group.groupColor.color }
    private var titleText: String {
        let trimmed = group.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Group" : trimmed
    }

    var body: some View {
        Button {
            withAnimation(MacDesign.springAnimation) {
                onToggleCollapse()
            }
        } label: {
            HStack(spacing: 4) {
                // Color dot
                Circle()
                    .fill(groupColor)
                    .frame(width: GroupHeaderMetrics.dotSize, height: GroupHeaderMetrics.dotSize)

                Text(titleText)
                    .font(.system(size: GroupHeaderMetrics.nameFontSize, weight: isHovered ? .semibold : .medium))
                    .foregroundStyle(Color.textPrimary)
                    .opacity(isHovered || group.isCollapsed ? 1.0 : 0.85)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if group.isCollapsed {
                    Text("\(group.tabCount)")
                        .font(.system(size: GroupHeaderMetrics.countFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(groupColor)
                        .padding(.horizontal, MacDesign.Spacing.small)
                        .padding(.vertical, MacDesign.Spacing.hairline)
                        .background(groupColor.opacity(0.15), in: Capsule())
                        .layoutPriority(0)
                }

                // Collapse indicator
                if !group.isCollapsed && isHovered {
                    Image(systemName: "chevron.down")
                         .font(.webTinyBold)
                        .foregroundStyle(Color.textSecondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, GroupHeaderMetrics.horizontalPadding)
            .padding(.vertical, GroupHeaderMetrics.verticalPadding)
            .frame(height: GroupHeaderMetrics.height)
            .background {
                RoundedRectangle(cornerRadius: GroupHeaderMetrics.cornerRadius, style: .continuous)
                    .fill(isHovered
                        ? groupColor.opacity(colorScheme == .dark ? 0.25 : 0.18)
                        : groupColor.opacity(colorScheme == .dark ? 0.15 : 0.10)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: GroupHeaderMetrics.cornerRadius, style: .continuous)
                    .stroke(groupColor.opacity(colorScheme == .dark ? 0.30 : 0.22), lineWidth: MacDesign.Spacing.hairlineThin)
            }
            .contentShape(RoundedRectangle(cornerRadius: GroupHeaderMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(MacDesign.fastAnimation) {
                isHovered = hovering
            }
        }
        .hoverCursor(.pointingHand)
        .contextMenu { contextMenuContent }
        .onTapGesture(count: 2) {
            isEditing = true
        }
        .popover(isPresented: $isEditing, arrowEdge: .bottom) {
            GroupEditPopover(
                group: group,
                onRename: onRename,
                onChangeColor: onChangeColor,
                onDismiss: { isEditing = false }
            )
        }
        .onAppear {
            if group.isNew {
                isEditing = true
                group.isNew = false
            }
        }
        .animation(MacDesign.fastAnimation, value: isHovered)
        .animation(MacDesign.springAnimation, value: group.isCollapsed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(titleText), tab group, \(group.tabCount) tabs, \(group.isCollapsed ? "collapsed" : "expanded")"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Double tap to toggle collapse. Use the context menu for more options."))
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(group.isCollapsed ? "Expand Group" : "Collapse Group") {
            onToggleCollapse()
        }

        Divider()

        Button("Rename Group") {
            isEditing = true
        }

        Menu("Change Color") {
            ForEach(TabGroupColor.allCases) { color in
                Button {
                    onChangeColor(color)
                } label: {
                    HStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 10, height: 10)
                        Text(color.displayName)
                        if color == group.groupColor {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()

        Button("Ungroup Tabs") {
            onUngroupTabs()
        }

        Divider()

        Button("Close Group", role: .destructive) {
            onCloseGroup()
        }

        Button("Delete Group Only") {
            onDeleteGroup()
        }
    }
}

private struct GroupEditPopover: View {
    var group: TabGroup
    let onRename: (String) -> Void
    let onChangeColor: (TabGroupColor) -> Void
    let onDismiss: () -> Void

    @State private var nameText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField("Name this group", text: $nameText)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    onRename(nameText)
                    onDismiss()
                }
                .onChange(of: nameText) { _, newValue in
                    onRename(newValue)
                }
                .onExitCommand {
                    onDismiss()
                }

            HStack(spacing: 8) {
                ForEach(TabGroupColor.allCases) { color in
                    Button {
                        onChangeColor(color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 16, height: 16)
                            .overlay {
                                if group.groupColor == color {
                                    Circle().stroke(Color.primary.opacity(0.3), lineWidth: 2)
                                        .padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .hoverCursor(.pointingHand)
                    .accessibilityLabel(Text(color.displayName))
                }
            }
        }
        .padding(MacDesign.Spacing.roomy)
        .frame(width: 220)
        .onAppear {
            nameText = group.name
            isFocused = true
        }
    }
}