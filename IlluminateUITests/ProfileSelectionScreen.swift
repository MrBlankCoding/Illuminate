//
//  ProfileSelectionScreen.swift
//  IlluminateUITests
//
// Created by MrBlankCoding on 4/4/26.
//

import XCTest

@MainActor
struct ProfileSelectionScreen {
    let app: XCUIApplication
    let defaultTimeout: TimeInterval

    private var title: XCUIElement {
        app.staticTexts["profileSelection.title"]
    }

    private var profileButtons: XCUIElementQuery {
        app.buttons.matching(identifier: "profileSelection.profileButton")
    }

    private var addProfileButton: XCUIElement {
        app.buttons["profileSelection.addProfileButton"]
    }

    private var guestModeButton: XCUIElement {
        app.buttons["profileSelection.guestModeButton"]
    }

    func waitUntilVisible(timeout: TimeInterval? = nil) -> Bool {
        title.waitForExistence(timeout: timeout ?? defaultTimeout)
    }

    func visibleProfileCount() -> Int {
        profileButtons.count
    }

    func hasPrimaryActions() -> Bool {
        addProfileButton.exists && guestModeButton.exists
    }

    func openDefaultProfile() -> BrowserScreen? {
        let firstProfile = profileButtons.firstMatch
        guard firstProfile.waitForExistence(timeout: defaultTimeout) else {
            return nil
        }

        firstProfile.click()
        let browser = BrowserScreen(app: app, defaultTimeout: defaultTimeout)
        return browser.waitUntilVisible() ? browser : nil
    }

    func openGuestMode() -> BrowserScreen? {
        guard guestModeButton.waitForExistence(timeout: defaultTimeout) else {
            return nil
        }

        guestModeButton.click()
        let browser = BrowserScreen(app: app, defaultTimeout: defaultTimeout)
        return browser.waitUntilVisible() ? browser : nil
    }
}
