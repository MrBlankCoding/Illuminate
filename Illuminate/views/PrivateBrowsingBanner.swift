//
//  PrivateBrowsingBanner.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/10/26.
//

import SwiftUI

struct PrivateBrowsingBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 11, weight: .semibold))
            Text("Private Browsing — History, cookies, and data won't be saved.")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.92))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(
            LinearGradient(
                colors: [Color(hex: "3A1F6E"), Color(hex: "1E1040")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .ignoresSafeArea(edges: .top)
    }
}
