//
//  UITestApp.swift
//  IlluminateUITests
//
// Created by MrBlankCoding on 4/4/26.
//

import XCTest

@MainActor
struct UITestApp {
    let app: XCUIApplication
    let defaultTimeout: TimeInterval

    func launch(resetState: Bool) async {
        app.launchArguments = resetState
            ? ["--ui-testing", "--ui-testing-reset-state"]
            : ["--ui-testing"]
        app.launch()
        activateWindowIfNeeded()
    }

    var profileSelection: ProfileSelectionScreen {
        ProfileSelectionScreen(app: app, defaultTimeout: defaultTimeout)
    }

    var browser: BrowserScreen {
        BrowserScreen(app: app, defaultTimeout: defaultTimeout)
    }

    func activateWindowIfNeeded(timeout: TimeInterval? = nil) {
        app.activate()

        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: timeout ?? defaultTimeout) else {
            return
        }

        window.click()
    }
}
