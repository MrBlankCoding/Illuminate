//
//  BrowserDownloadsUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class BrowserDownloadsUITests: BrowserUITestCase {
    override var additionalLaunchArguments: [String] { ["-uiTestingForceDownloadsButton"] }

    override func setUpWithError() throws {
        try super.setUpWithError()
        openGuestBrowser()
    }

    func testDownloadsToolbarOpensAndClosesItsEmptyPopover() {
        let downloadsButton = app.buttons["browser.toolbar.downloadsButton"]
        let emptyState = app.staticTexts["No Downloads"]

        XCTAssertTrue(downloadsButton.waitForExistence(timeout: 10))

        downloadsButton.tap()
        XCTAssertTrue(emptyState.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Files you download will appear here."].exists)

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(emptyState.waitForExistence(timeout: 2))
    }
}
