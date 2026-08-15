//
//  IlluminateUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 8/15/26.
//

import XCTest
import SwiftUI

final class IlluminateUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - 
        // required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppLaunchesSuccessfully() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.exists, "Application should launch successfully")
    }

    func testMainWindowExists() throws {
        let app = XCUIApplication()
        app.launch()
        
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window should exist")
    }

}
