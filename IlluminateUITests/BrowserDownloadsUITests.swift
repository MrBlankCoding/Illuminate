//
//  BrowserDownloadsUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class BrowserDownloadsUITests: BrowserUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openGuestBrowser()
    }

    func testDownloadsToolbarOpensAndClosesItsEmptyPopover() {
        let downloadsButton = app.buttons["browser.toolbar.downloadsButton"]
        let emptyState = app.staticTexts["No Downloads"]
        XCTAssertTrue(downloadsButton.waitForExistence(timeout: 2))
        XCTAssertFalse(emptyState.exists)

        downloadsButton.tap()
        XCTAssertTrue(emptyState.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Files you download will appear here."].exists)

        downloadsButton.tap()
        XCTAssertFalse(emptyState.waitForExistence(timeout: 1))
    }
}
