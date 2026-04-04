//
//  BrowserScreen.swift
//  IlluminateUITests
//
// Created by MrBlankCoding on 4/4/26.
//

import XCTest

@MainActor
struct BrowserScreen {
    let app: XCUIApplication
    let defaultTimeout: TimeInterval

    private var urlBar: XCUIElement {
        app.textFields["browser.urlBar.textField"]
    }

    private var newTabButton: XCUIElement {
        app.buttons["browser.sidebar.newTabButton"]
    }

    func waitUntilVisible(timeout: TimeInterval? = nil) -> Bool {
        urlBar.waitForExistence(timeout: timeout ?? defaultTimeout)
    }

    func isVisible() -> Bool {
        newTabButton.exists
    }

    func openSettingsWithShortcut() {
        urlBar.click()
        app.typeKey(",", modifierFlags: [.command])
    }

    func navigateToAddress(_ value: String) {
        guard urlBar.waitForExistence(timeout: defaultTimeout) else {
            return
        }

        urlBar.click()
        urlBar.typeKey("a", modifierFlags: [.command])
        urlBar.typeKey(XCUIKeyboardKey.delete.rawValue, modifierFlags: [])
        urlBar.typeText(value + XCUIKeyboardKey.return.rawValue)
    }

    func waitForURLBarValue(_ expectedValue: String, timeout: TimeInterval? = nil) -> Bool {
        waitForURLBar(predicate: NSPredicate(format: "value == %@", expectedValue), timeout: timeout)
    }

    func waitForURLBarValue(containing expectedFragment: String, timeout: TimeInterval? = nil) -> Bool {
        waitForURLBar(predicate: NSPredicate(format: "value CONTAINS %@", expectedFragment), timeout: timeout)
    }

    private func waitForURLBar(predicate: NSPredicate, timeout: TimeInterval? = nil) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: urlBar)
        return XCTWaiter.wait(for: [expectation], timeout: timeout ?? defaultTimeout) == .completed
    }
}
