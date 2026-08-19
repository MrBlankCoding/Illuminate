//
//  FaviconView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import AppKit
import SwiftUI

struct FaviconView: View {
    let image: NSImage?
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.69, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.19, style: .continuous))
    }
}
