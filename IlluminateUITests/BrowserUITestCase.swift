//
//  BrowserUITestCase.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

class BrowserUITestCase: XCTestCase {
    let app = XCUIApplication()

    var additionalLaunchArguments: [String] { [] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uiTesting"] + additionalLaunchArguments
        app.launch()

        _ = app.staticTexts["profileSelection.title"].waitForExistence(timeout: 20)
        print(">>> UI TEST DEBUG: windows=\(app.windows.count), buttons=\(app.buttons.count), staticTexts=\(app.staticTexts.count)")
        for (i, btn) in app.buttons.allElementsBoundByIndex.enumerated() {
            print(">>> UI TEST BUTTON [\(i)]: id=\(btn.identifier), label=\(btn.label)")
        }
        for (i, txt) in app.staticTexts.allElementsBoundByIndex.enumerated() {
            print(">>> UI TEST STATICTEXT [\(i)]: id=\(txt.identifier), label=\(txt.label), value=\(String(describing: txt.value))")
        }
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
