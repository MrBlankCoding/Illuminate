//
//  BrowserUITestCase.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

class BrowserUITestCase: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "com.MrBlankCoding.Illuminate")

    var additionalLaunchArguments: [String] { [] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uiTesting"] + additionalLaunchArguments
        app.launch()

        XCTAssertTrue(
            app.staticTexts["profileSelection.title"].waitForExistence(timeout: 20),
            "The profile selection screen should be ready before each UI test."
        )
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func openGuestBrowser() {
        app.buttons["profileSelection.guestModeButton"].tap()
        XCTAssertTrue(
            app.buttons["browser.tabbar.newTabButton"].waitForExistence(timeout: 20),
            "Guest mode should open the browser shell."
        )
    }
}
