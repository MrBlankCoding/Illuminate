//
//  BrowserAccessibilityUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class BrowserAccessibilityUITests: BrowserUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openGuestBrowser()
    }

    func testCoreBrowserShellControlsExposeUsefulAccessibilityLabels() {
        let controls = [
            app.buttons["browser.tabbar.newTabButton"],
            app.buttons["browser.navigation.backButton"],
            app.buttons["browser.navigation.forwardButton"],
            app.buttons["browser.navigation.reloadButton"],
            app.buttons["browser.newTab.customizeButton"],
            app.buttons["browser.toolbar.downloadsButton"],
        ]

        for control in controls {
            XCTAssertTrue(control.exists)
            XCTAssertFalse(control.label.isEmpty)
        }
    }

    func testNewTabSearchFieldIsReachableWhenBrowserOpens() {
        let urlBar = app.textFields["browser.urlBar.textField"]

        XCTAssertTrue(urlBar.waitForExistence(timeout: 10))
        XCTAssertTrue(urlBar.isHittable)
    }
}
