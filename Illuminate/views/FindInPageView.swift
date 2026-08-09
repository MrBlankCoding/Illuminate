//
//  FindInPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI

struct FindInPageView: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject var viewModel: FindViewModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
            
            TextField("Find in page", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    viewModel.findNext()
                }
            
            if !viewModel.searchText.isEmpty {
                Text(viewModel.matchFound ? "Found" : "No matches")
                    .font(.caption)
                    .foregroundStyle(viewModel.matchFound ? Color.textSecondary : .red)
                    .padding(.horizontal, 4)
            }
            
            Divider()
                .frame(height: 16)
            
            Group {
                Button {
                    viewModel.findPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .disabled(viewModel.searchText.isEmpty)
                
                Button {
                    viewModel.findNext()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .disabled(viewModel.searchText.isEmpty)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .floatingGlassPanel(cornerRadius: MacDesign.Radius.control)
        .onAppear {
            isSearchFocused = true
        }
    }
}
