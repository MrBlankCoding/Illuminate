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
                .foregroundColor(.secondary)
            
            TextField("Find in page", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    viewModel.findNext()
                }
            
            if !viewModel.searchText.isEmpty {
                Text(viewModel.matchFound ? "Found" : "No matches")
                    .font(.caption)
                    .foregroundColor(viewModel.matchFound ? .secondary : .red)
                    .padding(.horizontal, 4)
            }
            
            Divider()
                .frame(height: 16)
            
            Group {
                Button(action: { viewModel.findPrevious() }) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.searchText.isEmpty)
                
                Button(action: { viewModel.findNext() }) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.searchText.isEmpty)
            }
            .help("Previous/Next match")
            
            Button(action: { viewModel.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close search")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .floatingGlassPanel(cornerRadius: 10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            isSearchFocused = true
        }
    }
}
