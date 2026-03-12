//
//  SiteUnreachableView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI

struct SiteUnreachableView: View {
    @EnvironmentObject private var tabManager: TabManager
    let host: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(tabManager.windowThemeColor)
            
            VStack(spacing: 8) {
                Text("This site can’t be reached")
                    .font(.webH2)
                    .foregroundStyle(Color.textPrimary)
                
                Text("\(host)’s server IP address could not be found.")
                    .font(.webMicro)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 32)
            }
            
            Button {
                tabManager.activeTab?.reload()
            } label: {
                Text("Try Again")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(tabManager.windowThemeColor)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
        .glassBackground()
    }
}
