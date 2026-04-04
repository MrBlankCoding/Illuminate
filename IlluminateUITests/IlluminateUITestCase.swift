//
//  IlluminateUITestCase.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

class IlluminateUITestCase: XCTestCase {
    let defaultTimeout: TimeInterval = 5
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func launchApp(resetState: Bool) async {
        await uiTestApp.launch(resetState: resetState)
    }

    @MainActor
    var uiTestApp: UITestApp {
        UITestApp(app: app, defaultTimeout: defaultTimeout)
    }
}
