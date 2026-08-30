//
//  FindInPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI

struct FindInPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    var viewModel: FindViewModel
    let theme: BrowserTheme
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var viewModel = viewModel
        HStack(spacing: MacDesign.Spacing.control) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Find in page", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    viewModel.findNext()
                }

            if !viewModel.searchText.isEmpty {
                Text(matchLabel)
                    .font(.webMicro)
                    .monospacedDigit()
                    .foregroundStyle(viewModel.matchFound ? theme.accent : .red)
                    .padding(.horizontal, MacDesign.Spacing.control)
                    .padding(.vertical, MacDesign.Spacing.micro)
                    .liquidGlassCapsule(tint: viewModel.matchFound ? theme.accent : .red)
            }

            Divider()
                .frame(height: MacDesign.Spacing.roomy)

            Group {
                Button {
                    viewModel.findPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .disabled(!viewModel.matchFound)

                Button {
                    viewModel.findNext()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .disabled(!viewModel.matchFound)
            }
            .help("Previous/Next match")

            Button {
                viewModel.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.textSecondary)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .help("Close search")
        }
        .padding(.horizontal, MacDesign.Spacing.medium)
        .padding(.vertical, MacDesign.Spacing.control)
        .floatingGlassPanel(cornerRadius: MacDesign.Radius.control)
        .onAppear {
            isSearchFocused = true
            viewModel.accentColor = theme.accent
            if let webView = tabManager.activeTab?.webView {
                viewModel.attach(to: webView)
            }
        }
        .onChange(of: theme.accent) { _, newAccent in
            viewModel.accentColor = newAccent
        }
    }

    private var matchLabel: String {
        guard viewModel.matchFound else { return "No matches" }
        return "\(viewModel.currentMatchIndex + 1) of \(viewModel.totalMatches)"
    }
}