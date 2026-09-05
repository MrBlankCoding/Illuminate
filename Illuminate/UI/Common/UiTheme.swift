//
//  UiTheme.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/2/26.
//

import SwiftUI


extension Color {
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.primary.opacity(0.28)
    static let textQuaternary = Color.primary.opacity(0.18)
    static let borderSubtle = Color.primary.opacity(0.10)
    static let accentBeam = Color.accentColor
    static let suggestionRowHover = Color.primary.opacity(0.07)
}


struct BrowserTheme {
    static let defaultAccentHex = "4A90D9"
    static let defaultAccent = Color(hex: defaultAccentHex)

    let accent: Color
    let colorScheme: ColorScheme
    let windowThemeColor: Color

    var isDark: Bool { colorScheme == .dark }

    var windowBase: Color {
        isDark ? Color(hex: "161617") : Color(hex: "F5F5F7")
    }
    var toolbarBase: Color { windowThemeColor }
    var tabStripBackground: Color { windowThemeColor.slightlyDarker }
    var itemHover: Color { isDark ? Color.white.opacity(0.075) : Color.black.opacity(0.055) }
    var textOnAccent: Color { .white }
    static var guestAccent: Color { Color(hex: "7B52CC") }
}

enum BrowserAppearanceSettings {
    static let compactModeKey = "appearance.compactMode"
    static let animationsEnabledKey = "appearance.animationsEnabled"
}


enum MacDesign {
    enum Radius {
        static let micro: CGFloat = 4
        static let small: CGFloat = 7
        static let groupHeader: CGFloat = 6
        static let control: CGFloat = 10
        static let medium: CGFloat = 12
        static let card: CGFloat = 14
        static let large: CGFloat = 16
        static let panel: CGFloat = 20
        static let full: CGFloat = 999
    }

    enum Spacing {
        static let hairlineThin: CGFloat = 0.5
        static let hairline: CGFloat = 1
        static let micro: CGFloat = 2
        static let tiny: CGFloat = 3
        static let small: CGFloat = 4
        static let mini: CGFloat = 5
        static let tight: CGFloat = 6
        static let control: CGFloat = 8
        static let medium: CGFloat = 10
        static let regular: CGFloat = 12
        static let toolbarPadding: CGFloat = 14
        static let roomy: CGFloat = 16
        static let grid: CGFloat = 18
        static let section: CGFloat = 20
        static let page: CGFloat = 24
        static let pageHeaderPadding: CGFloat = 32
        static let largeSpacer: CGFloat = 72
    }

    enum Size {
        static let urlBarIcon: CGFloat = 22
        static let iconButton: CGFloat = 28
        static let largeIconButton: CGFloat = 32
        static let floatingButton: CGFloat = 36
        static let urlBarHeight: CGFloat = 34
        static let tabHeight: CGFloat = 34
        static let thumbnail: CGFloat = 52
        static let tabStripHeight: CGFloat = 42
        static let toolbarRowHeight: CGFloat = 48
        static let trafficLightWidth: CGFloat = 78
        static let sidePanelWidth: CGFloat = 260
        static let sidePanelContentWidth: CGFloat = 228
        static let newTabGridMax: CGFloat = 560
        static let internalPageMax: CGFloat = 680
    }

    static let fastAnimation = Animation.easeInOut(duration: 0.16)
    static let springAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let popupAnimation = Animation.spring(response: 0.2, dampingFraction: 0.8)
}

extension Font {
    static let webHero = Font.system(size: 40, weight: .semibold, design: .rounded)
    static let webInternalPageTitle = Font.system(size: 26, weight: .bold, design: .rounded)
    static let webH2 = Font.system(size: 20, weight: .medium)
    static let webInternalPageIcon = Font.system(size: 22, weight: .semibold)
    static let webMonogram = Font.system(size: 18, weight: .medium, design: .rounded)
    static let webBody = Font.system(size: 14)
    static let webCaption = Font.system(size: 13)
    static let webCaptionBold = Font.system(size: 13, weight: .semibold)
    static let webCaptionMonospaced = Font.system(size: 13).monospaced()
    static let webMicro = Font.system(size: 12.5)
    static let webMicroMedium = Font.system(size: 12.5, weight: .medium)
    static let webSmallRegular = Font.system(size: 11)
    static let webSmallRegularMedium = Font.system(size: 11, weight: .medium)
    static let webSmall = Font.system(size: 10)
    static let webSmallBold = Font.system(size: 10, weight: .bold)
    static let webTinyBold = Font.system(size: 8, weight: .bold)
    static let webBadge = Font.system(size: 7.5, weight: .bold, design: .rounded)
}
