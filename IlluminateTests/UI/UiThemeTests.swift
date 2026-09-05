//
//  UiThemeTests.swift
//  IlluminateTests
//
//  Created by MrBlankCode on 3/11/26.
//

import SwiftUI
import Testing

@testable import Illuminate

struct UiThemeTests {

    @Test func browserThemesExposeLightAndDarkValues() {
        let light = BrowserTheme(accent: .blue, colorScheme: .light, windowThemeColor: .white)
        let dark = BrowserTheme(accent: .orange, colorScheme: .dark, windowThemeColor: .black)
        #expect(light.isDark == false)
        #expect(dark.isDark == true)
        _ = [
            light.windowBase, light.windowThemeColor, light.tabStripBackground,
            light.itemHover, light.textOnAccent, BrowserTheme.guestAccent
        ]
        _ = [
            dark.windowBase, dark.windowThemeColor, dark.tabStripBackground,
            dark.itemHover, dark.textOnAccent, BrowserTheme.guestAccent
        ]
    }

    @Test func defaultAccentConstantsAreConsistent() {
        #expect(BrowserTheme.defaultAccentHex == "4A90D9")
        #expect(BrowserTheme.defaultAccent == Color(hex: BrowserTheme.defaultAccentHex))
        #expect(BrowserTheme.guestAccent == Color(hex: "7B52CC"))
    }

    @Test func colorsRoundTripThroughHexFormats() {
        #expect(Color(hex: "#fff").hexString() == "FFFFFF")
        #expect(Color(hex: "112233").hexString() == "112233")
        #expect(Color(hex: "80112233").hexString() == "11223380")
        #expect(Color(hex: "invalid").hexString() == "000000")
        _ = Color.red.blended(with: .blue, fraction: 0.5)
    }

    @Test func slightlyDarkerProducesDarkerVariant() {
        let base = Color.AppColor.hsl(h: 0.3, s: 0.8, l: 0.6)
        let darker = base.slightlyDarker
        let baseL = Color.AppColor.hslComponents(of: base).l
        let darkerL = Color.AppColor.hslComponents(of: darker).l
        #expect(darkerL < baseL)
        #expect(abs(darkerL - max(0.0, baseL - 0.12)) < 1e-3)
    }

    @Test func browserThemeExposesTabStripBackground() {
        let light = BrowserTheme(accent: .blue, colorScheme: .light, windowThemeColor: Color(hex: "808080"))
        let dark = BrowserTheme(accent: .orange, colorScheme: .dark, windowThemeColor: Color(hex: "404040"))
        let lightBgL = Color.AppColor.hslComponents(of: light.tabStripBackground).l
        let lightBaseL = Color.AppColor.hslComponents(of: light.windowThemeColor).l
        let darkBgL = Color.AppColor.hslComponents(of: dark.tabStripBackground).l
        let darkBaseL = Color.AppColor.hslComponents(of: dark.windowThemeColor).l
        #expect(lightBgL < lightBaseL)
        #expect(darkBgL < darkBaseL)
    }

    @Test func designSystemModifiersAndConstantsAreConstructible() {
        _ = MacDesign.Size.iconButton
        _ = MacDesign.Radius.medium
        _ = MacDesign.Spacing.roomy
        _ = MacDesign.fastAnimation
        _ = MacDesign.springAnimation
        _ = Text("content").glassBackground()
        _ = Text("content").liquidGlassCapsule(tint: .blue, padding: 4)
        _ = Text("content").browserPanel()
        _ = Text("content").insetPanel()
        _ = Text("content").floatingGlassPanel()
        _ = Text("content").macPopover()
        _ = Text("content").macControlBackground(isActive: true, isHovered: true, tint: .blue)
        _ = Text("content").focusRing(true)
        _ = Text("content").navClusterBackground()
        _ = Text("content").hoverCursor(.arrow)
        _ = CavedDivider().body
    }
}
