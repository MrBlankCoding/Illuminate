//
//  IlluminateUITests.swift
//  IlluminateUITests
//

import XCTest

final class IlluminateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testProfileSelectionScreenShowsPrimaryActions() {
        launchApp(resetState: true)

        XCTAssertTrue(app.staticTexts["profileSelection.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "profileSelection.profileButton").count, 1)
        XCTAssertTrue(app.buttons["profileSelection.addProfileButton"].exists)
        XCTAssertTrue(app.buttons["profileSelection.guestModeButton"].exists)
    }

    func testGuestModeLaunchesBrowserShell() {
        launchApp(resetState: true)

        app.buttons["profileSelection.guestModeButton"].click()

        XCTAssertTrue(app.textFields["browser.urlBar.textField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.sidebar.newTabButton"].exists)
        XCTAssertEqual(app.otherElements.matching(identifier: "browser.sidebar.tabRow").count, 1)
    }

    func testAddingProfileNavigatesIntoBrowserSession() {
        launchApp(resetState: true)

        app.buttons["profileSelection.addProfileButton"].click()
        XCTAssertTrue(app.otherElements["profileSelection.addProfileSheet"].waitForExistence(timeout: 5))

        let nameField = app.textFields["profileSelection.addProfileNameField"]
        XCTAssertTrue(nameField.exists)
        nameField.click()
        nameField.typeText("Work")

        let addButton = app.buttons["profileSelection.confirmAddProfileButton"]
        XCTAssertTrue(addButton.isEnabled)
        addButton.click()

        XCTAssertTrue(app.textFields["browser.urlBar.textField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.sidebar.newTabButton"].exists)
    }

    func testCreatingNewTabAddsSidebarEntry() {
        launchApp(resetState: true)
        openDefaultProfile()

        let initialCount = app.otherElements.matching(identifier: "browser.sidebar.tabRow").count
        app.buttons["browser.sidebar.newTabButton"].click()

        XCTAssertEqual(
            app.otherElements.matching(identifier: "browser.sidebar.tabRow").count,
            initialCount + 1
        )
    }

    func testInternalSettingsRouteShowsSettingsScreen() {
        launchApp(resetState: true)
        openDefaultProfile()

        let urlBar = app.textFields["browser.urlBar.textField"]
        XCTAssertTrue(urlBar.waitForExistence(timeout: 5))
        urlBar.click()
        urlBar.typeText("illuminate://settings\n")

        XCTAssertTrue(app.otherElements["settings.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.tab.appearance"].exists)
        XCTAssertTrue(app.buttons["settings.tab.passwords"].exists)
    }

    private func launchApp(resetState: Bool) {
        var launchArguments = ["--ui-testing"]
        if resetState {
            launchArguments.append("--ui-testing-reset-state")
        }

        app.launchArguments = launchArguments
        app.launch()
    }

    private func openDefaultProfile() {
        let firstProfile = app.buttons.matching(identifier: "profileSelection.profileButton").firstMatch
        XCTAssertTrue(firstProfile.waitForExistence(timeout: 5))
        firstProfile.click()
        XCTAssertTrue(app.textFields["browser.urlBar.textField"].waitForExistence(timeout: 5))
    }
}
