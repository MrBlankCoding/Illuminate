//
//  BrowserTabsUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class BrowserTabsUITests: BrowserUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openGuestBrowser()
    }

    func testTabStripExposesCurrentTabAndTabControls() {
        let tabBar = app.descendants(matching: .any)["browser.tabbar"].firstMatch

        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        XCTAssertEqual(tabBar.label, "Tab strip, 1 tab")
        XCTAssertTrue(app.buttons["browser.tabbar.newTabButton"].isEnabled)
        XCTAssertTrue(app.buttons["browser.tabbar.closeTabButton"].exists)
    }

    func testCustomizeButtonPresentsAndDismissesNewTabPanel() {
        let customizeButton = app.buttons["browser.newTab.customizeButton"]
        let panelTitle = app.staticTexts["Customize"]
        XCTAssertTrue(customizeButton.waitForExistence(timeout: 10))
        XCTAssertFalse(panelTitle.exists)

        customizeButton.tap()
        XCTAssertTrue(panelTitle.waitForExistence(timeout: 10))

        customizeButton.tap()
        XCTAssertFalse(panelTitle.waitForExistence(timeout: 1))
    }
}
