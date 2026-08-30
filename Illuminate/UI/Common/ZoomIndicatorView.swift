//
//  ZoomIndicatorView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI

struct ZoomIndicatorView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    var viewModel: ZoomViewModel
    
    var body: some View {
        HStack(spacing: MacDesign.Spacing.control) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
            
            Button {
                tabManager.activeTab?.zoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.webSmallBold)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            
            Button(action: { tabManager.activeTab?.resetZoom() }) {
                Text("\(Int(round(viewModel.zoomLevel * 100)))%")
                    .font(.webCaptionBold.monospacedDigit())
                    .frame(minWidth: 44)
            }
            .buttonStyle(.plain)
            .help("Reset Zoom")
            
            Button {
                tabManager.activeTab?.zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.webSmallBold)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: MacDesign.Spacing.roomy)
            
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
        .padding(.horizontal, MacDesign.Spacing.medium)
        .padding(.vertical, MacDesign.Spacing.control)
        .floatingGlassPanel(cornerRadius: MacDesign.Radius.control)
    }
}
