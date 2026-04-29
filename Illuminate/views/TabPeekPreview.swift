//
//  TabPeekPreview.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI

struct TabPeekPreview: View {
    let image: NSImage?
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.textSecondary)
                    Text("No preview available")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.06))
            }
        }
        .frame(width: 220, height: 140)
        .clipped()
        .glassBackground(cornerRadius: 12)
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 10)
    }
}
