//
//  EaselListView.swift
//  Illuminate 
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI

struct EaselListView: View {
    @Environment(ProfileEnvironment.self) private var env
    @Environment(TabManager.self) private var tabManager

    var body: some View {
        InternalPage(icon: "paintbrush.pointed.fill", title: "Easels", accentColor: tabManager.windowThemeColor) {
            VStack(spacing: MacDesign.Spacing.section) {
                header
                grid
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(env.easelManager.easels.count) easel\(env.easelManager.easels.count == 1 ? "" : "s")")
                .font(.webSmall)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                createEasel()
            } label: {
                Label("New Easel", systemImage: "plus")
            }
            .buttonStyle(InternalPageChipButtonStyle(color: tabManager.windowThemeColor))
            .accessibilityIdentifier("easel.newButton")
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)], spacing: 16) {
            ForEach(env.easelManager.easels) { easel in
                EaselCard(easel: easel, onOpen: { open(easel) }, onRename: { new in
                    env.easelManager.renameEasel(id: easel.id, to: new)
                }, onDelete: {
                    env.easelManager.deleteEasel(id: easel.id)
                })
            }
        }
    }

    private func createEasel() {
        let easel = env.easelManager.createEasel()
        tabManager.createTab(url: easel.url)
    }

    private func open(_ easel: Easel) {
        tabManager.createTab(url: easel.url)
    }
}

private struct EaselCard: View {
    let easel: Easel
    var onOpen: () -> Void
    var onRename: (String) -> Void
    var onDelete: () -> Void
    @Environment(ProfileEnvironment.self) private var env

    @State private var isRenaming = false
    @State private var draftTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let preview = env.easelManager.previewImage(for: easel.id) {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: MacDesign.Radius.control).fill(Color.primary.opacity(0.04))
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.control))
            .overlay(alignment: .bottomLeading) {
                Text(easel.title).font(.webCaption.weight(.semibold)).lineLimit(1)
                    .padding(8)
                    .glassEffect(.regular, in: Capsule())
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isRenaming {
                    TextField("Title", text: $draftTitle, onCommit: {
                        onRename(draftTitle)
                        isRenaming = false
                    })
                    .textFieldStyle(.roundedBorder)
                } else {
                    Text(easel.title).font(.headline).lineLimit(1)
                }
                HStack {
                    Button("Open") { onOpen() }.buttonStyle(.borderedProminent).controlSize(.small)
                    Spacer()
                    Menu {
                        Button("Rename") { draftTitle = easel.title; isRenaming = true }
                        Button("Delete", role: .destructive) { onDelete() }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MacDesign.Radius.card).strokeBorder(Color.primary.opacity(0.08)))
    }
}
