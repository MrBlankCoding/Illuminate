//
//  IlluminateUITestCase.swift
//  IlluminateUITests
//

import XCTest

@MainActor
class IlluminateUITestCase: XCTestCase {
    let defaultTimeout: TimeInterval = 5
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func launchApp(resetState: Bool) async {
        var launchArguments = ["--ui-testing"]
        if resetState {
            launchArguments.append("--ui-testing-reset-state")
        }

        app.launchArguments = launchArguments
        app.launch()
        await activateAppWindowIfNeeded()
    }

    func openDefaultProfile() async {
        let firstProfile = app.buttons.matching(identifier: "profileSelection.profileButton").firstMatch
        let profileExists = await waitForExistence(of: firstProfile)
        XCTAssertTrue(profileExists)

        await activateAppWindowIfNeeded()
        firstProfile.click()

        let urlBarExists = await waitForExistence(of: app.textFields["browser.urlBar.textField"])
        XCTAssertTrue(urlBarExists)
    }

    func typeKeyboardShortcut(_ key: String, modifierFlags: XCUIElement.KeyModifierFlags) async {
        await activateAppWindowIfNeeded()
        app.typeKey(key, modifierFlags: modifierFlags)
    }

    func submitReturnKey() async {
        await activateAppWindowIfNeeded()
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
    }

    func waitForURLBarValue(_ expectedValue: String, timeout: TimeInterval? = nil) async -> Bool {
        let urlBar = app.textFields["browser.urlBar.textField"]
        return await waitForElement(timeout: timeout ?? defaultTimeout) {
            (urlBar.value as? String) == expectedValue
        }
    }

    func waitForURLBarValue(containing expectedFragment: String, timeout: TimeInterval? = nil) async -> Bool {
        let urlBar = app.textFields["browser.urlBar.textField"]
        return await waitForElement(timeout: timeout ?? defaultTimeout) {
            (urlBar.value as? String)?.contains(expectedFragment) == true
        }
    }

    func waitForExistence(of element: XCUIElement, timeout: TimeInterval? = nil) async -> Bool {
        await waitForElement(timeout: timeout ?? defaultTimeout) {
            element.exists
        }
    }

    func activateAppWindowIfNeeded(timeout: TimeInterval? = nil) async {
        app.activate()

        let window = app.windows.firstMatch
        let didFindWindow = await waitForExistence(of: window, timeout: timeout ?? defaultTimeout)
        guard didFindWindow else {
            return
        }

        if !window.hasFocus {
            window.click()
        }
    }

    private func waitForElement(
        timeout: TimeInterval,
        pollIntervalNanoseconds: UInt64 = 100_000_000,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return condition()
    }
}
