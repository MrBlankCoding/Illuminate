//
//  ThemeEditorView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI

struct ThemeEditorView: View {
    @Binding var theme: IlluminateTheme
    @State private var selectedColorID: UUID?

    init(theme: Binding<IlluminateTheme>) {
        self._theme = theme
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Background
                Color(white: 0.06)
                
                VStack(spacing: 0) {
                    upperSection
                        .frame(height: geo.size.height / 2)
                    
                    lowerSection
                        .frame(height: geo.size.height / 2)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        .onAppear {
            if selectedColorID == nil {
                selectedColorID = theme.colors.first?.id
            }
        }
    }

    private var upperSection: some View {
        ZStack(alignment: .top) {
            ThemeCanvas(theme: $theme, selectedColorID: $selectedColorID)

            ThemeModeSelector(scheme: $theme.colorScheme)
                .padding(.top, 22)
        }
    }

    private var lowerSection: some View {
        VStack(spacing: 20) {
            ThemePresetPalette(theme: $theme, selectedColorID: $selectedColorID)
                .padding(.horizontal, 20)
                .padding(.top, 18)

            HStack(alignment: .center, spacing: 18) {
                ThemeWaveSlider(value: $theme.opacity)
                ThemeTextureDial(value: $theme.texture)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
    }
}

#Preview("Theme Editor") {
    ThemeEditorPreviewContainer()
        .frame(width: 378, height: 512)
        .padding(24)
        .background(Color.black)
}

private struct ThemeEditorPreviewContainer: View {
    @State private var theme = IlluminateTheme.default

    var body: some View {
        ThemeEditorView(theme: $theme)
    }
}
