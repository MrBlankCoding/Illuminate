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
                .foregroundStyle(Color.textSecondary)
            
            Button {
                tabManager.activeTab?.zoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            
            Button(action: { tabManager.activeTab?.resetZoom() }) {
                Text("\(Int(round(viewModel.zoomLevel * 100)))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(minWidth: 44)
            }
            .buttonStyle(.plain)
            .help("Reset Zoom")
            
            Button {
                tabManager.activeTab?.zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 16)
            
            Button {
                viewModel.hide()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.textSecondary)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .floatingGlassPanel(cornerRadius: MacDesign.Radius.control)
    }
}
