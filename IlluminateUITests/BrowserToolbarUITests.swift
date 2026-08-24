//
//  BrowserToolbarUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class BrowserToolbarUITests: BrowserUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openGuestBrowser()
    }

    func testNavigationControlsAreDisabledForANewTab() {
        XCTAssertFalse(app.buttons["browser.navigation.backButton"].isEnabled)
        XCTAssertFalse(app.buttons["browser.navigation.forwardButton"].isEnabled)
        XCTAssertFalse(app.buttons["browser.navigation.reloadButton"].isEnabled)
    }

    func testAddressBarOpensNativeHistoryPage() {
        let addressBar = app.textFields["browser.urlBar.textField"]
        XCTAssertTrue(addressBar.waitForExistence(timeout: 10))

        addressBar.click()
        addressBar.typeText("illuminate://history")
        addressBar.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            app.staticTexts["browser.internalPage.history"].waitForExistence(timeout: 10),
            "The address bar should route illuminate://history to the native History page."
        )
    }
}
