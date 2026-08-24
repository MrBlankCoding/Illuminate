//
//  BrowserInternalPagesUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class BrowserInternalPagesUITests: BrowserUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openGuestBrowser()
    }

    func testHistoryPageExplainsGuestHistoryIsEmpty() {
        openInternalPage("history")

        XCTAssertTrue(app.staticTexts["browser.internalPage.history"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your browsing history will appear here."].exists)
    }

    func testDownloadsPageExplainsWhereDownloadsAppear() {
        openInternalPage("downloads")

        XCTAssertTrue(app.staticTexts["browser.internalPage.downloads"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Files you download will appear here."].exists)
    }

    func testPasswordsPageExplainsGuestSessionsDoNotSavePasswords() {
        openInternalPage("passwords")

        XCTAssertTrue(app.staticTexts["browser.internalPage.passwords"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Passwords aren't saved in Guest sessions."].exists)
    }

    func testPermissionsPageShowsEmptyStateBeforeAnyWebsiteRequestsAccess() {
        openInternalPage("permissions")

        XCTAssertTrue(app.staticTexts["browser.internalPage.permissions"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No websites have requested permissions yet."].exists)
    }

    func testCookiesControlsAreExposedOnProtectionPage() {
        openInternalPage("protection")

        let cookiesToggle = app.descendants(matching: .any)["browser.cookies.enabledToggle"].firstMatch
        let clearButton = app.buttons["browser.cookies.clearButton"]
        XCTAssertTrue(cookiesToggle.waitForExistence(timeout: 10))
        XCTAssertTrue(clearButton.exists)
        XCTAssertFalse(cookiesToggle.label.isEmpty)
    }


    func testProtectionPageExposesTrackerLearningConfiguration() {
        openInternalPage("protection")

        let learningToggle = app.descendants(matching: .any)["browser.protection.trackerLearningToggle"].firstMatch
        let threshold = app.descendants(matching: .any)["browser.protection.learnThresholdStepper"].firstMatch
        XCTAssertTrue(learningToggle.waitForExistence(timeout: 10))
        XCTAssertTrue(threshold.exists)
        XCTAssertFalse(learningToggle.label.isEmpty)
    }

    private func openInternalPage(_ page: String) {
        let addressBar = app.textFields["browser.urlBar.textField"]
        XCTAssertTrue(addressBar.waitForExistence(timeout: 10))
        addressBar.click()
        addressBar.typeText("illuminate://\(page)")
        addressBar.typeKey(.return, modifierFlags: [])
    }
}
