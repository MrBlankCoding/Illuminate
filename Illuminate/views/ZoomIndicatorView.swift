//
//  ZoomIndicatorView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI

struct ZoomIndicatorView: View {
    @EnvironmentObject private var tabManager: TabManager
    @ObservedObject var viewModel: ZoomViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            Button(action: { tabManager.activeTab?.zoomOut() }) {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            
            Button(action: { tabManager.activeTab?.resetZoom() }) {
                Text("\(Int(round(viewModel.zoomLevel * 100)))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(minWidth: 44)
            }
            .buttonStyle(.plain)
            .help("Reset Zoom")
            
            Button(action: { tabManager.activeTab?.zoomIn() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 16)
            
            Button(action: { viewModel.hide() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .floatingGlassPanel(cornerRadius: 10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
