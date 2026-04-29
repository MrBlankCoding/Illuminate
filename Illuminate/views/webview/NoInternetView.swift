//
//  NoInternetView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct NoInternetView: View {
    @EnvironmentObject private var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme
    let message: String

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(tabManager.windowThemeColor)
            
            Text("No Internet")
                .font(.webH2)
                .foregroundStyle(Color.textPrimary)
            
            Text(message)
                .font(.webMicro)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBase)
        .glassBackground()
    }
}
