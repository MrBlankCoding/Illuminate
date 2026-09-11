//
//  UiTheme.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/2/26.
//

import SwiftUI
import Combine


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
    static let guestAccentHex = "8E8E93"

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
    static var guestAccent: Color { Color(hex: guestAccentHex) }
}

enum BrowserAppearanceSettings {
    static let compactModeKey = "appearance.compactMode"
    static let animationsEnabledKey = "appearance.animationsEnabled"
    static let colorSchemeKey = "appearance.colorScheme"

    static let compactModeDidChangeNotification = Notification.Name("BrowserAppearanceSettings.compactModeDidChange")
}

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@Observable
class AppearanceSettings {
    static let shared = AppearanceSettings()

    var compactMode: Bool {
        didSet {
            UserDefaults.standard.set(compactMode, forKey: BrowserAppearanceSettings.compactModeKey)
            NotificationCenter.default.post(name: BrowserAppearanceSettings.compactModeDidChangeNotification, object: nil)
        }
    }

    var colorScheme: AppColorScheme {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: BrowserAppearanceSettings.colorSchemeKey)
            NSApp.appearance = colorScheme.nsAppearance
        }
    }

    private init() {
        self.compactMode = UserDefaults.standard.bool(forKey: BrowserAppearanceSettings.compactModeKey)
        let savedColorScheme = UserDefaults.standard.string(forKey: BrowserAppearanceSettings.colorSchemeKey)
        self.colorScheme = AppColorScheme(rawValue: savedColorScheme ?? "") ?? .system
        NSApp.appearance = self.colorScheme.nsAppearance
    }

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
        static var hairlineThin: CGFloat { compactMode ? 0.5 : 0.5 }
        static var hairline: CGFloat { compactMode ? 1 : 1 }
        static var micro: CGFloat { compactMode ? 1 : 2 }
        static var tiny: CGFloat { compactMode ? 2 : 3 }
        static var small: CGFloat { compactMode ? 3 : 4 }
        static var mini: CGFloat { compactMode ? 4 : 5 }
        static var tight: CGFloat { compactMode ? 5 : 6 }
        static var control: CGFloat { compactMode ? 6 : 8 }
        static var medium: CGFloat { compactMode ? 8 : 10 }
        static var regular: CGFloat { compactMode ? 10 : 12 }
        static var toolbarPadding: CGFloat { compactMode ? 10 : 14 }
        static var roomy: CGFloat { compactMode ? 12 : 16 }
        static var grid: CGFloat { compactMode ? 14 : 18 }
        static var section: CGFloat { compactMode ? 16 : 20 }
        static var page: CGFloat { compactMode ? 18 : 24 }
        static var pageHeaderPadding: CGFloat { compactMode ? 24 : 32 }
        static var largeSpacer: CGFloat { compactMode ? 56 : 72 }
        
        private static var compactMode: Bool {
            UserDefaults.standard.bool(forKey: BrowserAppearanceSettings.compactModeKey)
        }
    }

    enum Size {
        static var urlBarIcon: CGFloat { compactMode ? 20 : 22 }
        static var iconButton: CGFloat { compactMode ? 26 : 28 }
        static var largeIconButton: CGFloat { compactMode ? 30 : 32 }
        static var floatingButton: CGFloat { compactMode ? 34 : 36 }
        static var urlBarHeight: CGFloat { compactMode ? 30 : 34 }
        static var tabHeight: CGFloat { compactMode ? 30 : 34 }
        static var thumbnail: CGFloat { compactMode ? 48 : 52 }
        static var tabStripHeight: CGFloat { compactMode ? 38 : 42 }
        static var toolbarRowHeight: CGFloat { compactMode ? 44 : 48 }
        static var trafficLightWidth: CGFloat { compactMode ? 78 : 78 }
        static var sidePanelWidth: CGFloat { compactMode ? 240 : 260 }
        static var sidePanelContentWidth: CGFloat { compactMode ? 208 : 228 }
        static var newTabGridMax: CGFloat { compactMode ? 540 : 560 }
        static var internalPageMax: CGFloat { compactMode ? 660 : 680 }
        
        private static var compactMode: Bool {
            UserDefaults.standard.bool(forKey: BrowserAppearanceSettings.compactModeKey)
        }
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

// View modifier to respond to compact mode changes
struct CompactModeAware: ViewModifier {
    @State private var compactModeVersion = UUID()
    
    func body(content: Content) -> some View {
        content
            .id(compactModeVersion)
            .onReceive(NotificationCenter.default.publisher(for: BrowserAppearanceSettings.compactModeDidChangeNotification)) { _ in
                compactModeVersion = UUID()
            }
    }
}

extension View {
    func compactModeAware() -> some View {
        modifier(CompactModeAware())
    }
}
