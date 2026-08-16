//
//  IlluminateUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class ProfileSelectionUITests: BrowserUITestCase {

    func testLaunchShowsProfileSelectionActions() {
        XCTAssertTrue(app.buttons["profileSelection.addProfileButton"].exists)
        XCTAssertTrue(app.buttons["profileSelection.guestModeButton"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "profileSelection.profileButton").count, 2)
    }

    func testAddProfileSheetPresentsAndCancelsWithoutMutation() {
        app.buttons["profileSelection.addProfileButton"].tap()

        let sheetTitle = app.staticTexts["New Profile"]
        let confirmButton = app.buttons["Add"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 2))
        XCTAssertFalse(confirmButton.isEnabled)

        app.buttons["Cancel"].tap()
        XCTAssertFalse(sheetTitle.waitForExistence(timeout: 1))
    }

}
