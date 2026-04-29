//
//  SidebarHeader.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import WebKit

struct SidebarHeader: View {
    let tab: Tab?

    var body: some View {
        Button {
            if tab?.isLoading == true {
                tab?.webView?.stopLoading()
            } else {
                tab?.webView?.reload()
            }
        } label: {
            Image(systemName: tab?.isLoading == true ? "xmark" : "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.borderSubtle, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
