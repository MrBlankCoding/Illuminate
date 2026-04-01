//
//  PlaceholderView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct PlaceholderView: View {
    @EnvironmentObject private var tabManager: TabManager

    var body: some View {
        VStack(spacing: 12) {
            Text("Open a new tab to begin.")
                .font(.webBody)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
