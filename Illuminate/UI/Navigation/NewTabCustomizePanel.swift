//
//  NewTabCustomizePanel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct NewTabCustomizePanel: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundLabel: String {
        guard !tabManager.backgroundImageURL.isEmpty,
              let url = URL(string: tabManager.backgroundImageURL)
        else { return "None" }
        let name = url.lastPathComponent
        return name.isEmpty ? "Custom URL" : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Customize", systemImage: "paintbrush.pointed.fill")
                    .font(.webCaptionBold)
                    .foregroundStyle(tabManager.windowThemeColor)
                Spacer()
            }
            .padding(.horizontal, MacDesign.Spacing.roomy)
            .padding(.top, MacDesign.Spacing.section)
            .padding(.bottom, MacDesign.Spacing.toolbarPadding)

            Divider()
                .frame(maxWidth: .infinity)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: MacDesign.Spacing.page) {
                    sidebarSection(title: "Appearance") {
                        Text("Auto-determined from image")
                                .font(.webMicroMedium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, MacDesign.Spacing.small)
                    }

                    sidebarSection(title: "Background Image") {
                        VStack(alignment: .leading, spacing: MacDesign.Spacing.regular) {
                            HStack(alignment: .top, spacing: MacDesign.Spacing.regular) {
                                backgroundThumbnail

                                VStack(alignment: .leading, spacing: MacDesign.Spacing.small) {
                                    Text(backgroundLabel)
                                        .font(.webMicroMedium)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Text(
                                        tabManager.backgroundImageURL.isEmpty
                                            ? "No image set"
                                            : tabManager.backgroundImageURL
                                    )
                                    .font(.webCaptionMonospaced)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: MacDesign.Spacing.control) {
                                Button {
                                    chooseBackgroundImage()
                                } label: {
                                    Label("Choose…", systemImage: "folder")
                                        .font(.webMicro)
                                        .padding(.horizontal, MacDesign.Spacing.medium)
                                        .padding(.vertical, MacDesign.Spacing.mini)
                                        .liquidGlassCapsule()
                                }
                                .buttonStyle(.plain)

                                if !tabManager.backgroundImageURL.isEmpty {
                                    Button {
                                        withAnimation(MacDesign.fastAnimation) {
                                            tabManager.backgroundImageURL = ""
                                        }
                                    } label: {
                                        Label("Remove", systemImage: "xmark")
                                            .font(.webMicro)
                                            .padding(.horizontal, MacDesign.Spacing.medium)
                                            .padding(.vertical, MacDesign.Spacing.mini)
                                            .liquidGlassCapsule(tint: .red)
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                .frame(width: MacDesign.Size.sidePanelContentWidth, alignment: .leading)
                .padding(.horizontal, MacDesign.Spacing.roomy)
                .padding(.vertical, MacDesign.Spacing.section)
            }

            .frame(maxWidth: .infinity)
        }
        .frame(width: MacDesign.Size.sidePanelWidth)
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier("browser.newTab.customizePanel")
        .glassEffect(.regular, in: .rect)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(width: MacDesign.Spacing.hairlineThin)
        }
    }

    @ViewBuilder
    private func sidebarSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: MacDesign.Spacing.medium) {
            Text(title.uppercased())
                .font(.webSmallBold)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            content()
        }
    }

    @ViewBuilder
    private var backgroundThumbnail: some View {
        let size: CGFloat = MacDesign.Size.thumbnail
        ZStack {
            RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous)
                .fill(Color.textQuaternary)

            if !tabManager.backgroundImageURL.isEmpty,
               let url = URL(string: tabManager.backgroundImageURL) {
                CachedBackgroundImageView(url: url)
                    .clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.webH2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: MacDesign.Spacing.hairlineThin)
        }
    }

    private func chooseBackgroundImage() {
        let urls = FilePanels.chooseFiles(
            allowedContentTypes: [.image],
            message: "Choose an image for your new tab page background",
            prompt: "Set Background"
        )
        if let url = urls.first {
            tabManager.backgroundImageURL = url.absoluteString
        }
    }
}