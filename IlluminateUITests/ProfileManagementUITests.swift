//
//  ProfileManagementUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class ProfileManagementUITests: IlluminateUITestCase {
    func testProfileSelectionScreenShowsPrimaryActions() async {
        await launchApp(resetState: true)

        let profileSelection = await MainActor.run { uiTestApp.profileSelection }
        let titleExists = await MainActor.run { profileSelection.waitUntilVisible() }
        let profileButtonCount = await MainActor.run { profileSelection.visibleProfileCount() }
        let hasPrimaryActions = await MainActor.run { profileSelection.hasPrimaryActions() }

        XCTAssertTrue(titleExists)
        XCTAssertEqual(profileButtonCount, 1)
        XCTAssertTrue(hasPrimaryActions)
    }

    func testGuestModeLaunchesBrowserShell() async {
        await launchApp(resetState: true)

        let profileSelection = await MainActor.run { uiTestApp.profileSelection }
        let browser = await MainActor.run { profileSelection.openGuestMode() }
        let browserShellIsVisible = await MainActor.run { browser?.isVisible() ?? false }

        XCTAssertNotNil(browser)
        XCTAssertTrue(browserShellIsVisible)
    }

    func testDefaultProfileLaunchesBrowserShell() async {
        await launchApp(resetState: true)

        let profileSelection = await MainActor.run { uiTestApp.profileSelection }
        let browser = await MainActor.run { profileSelection.openDefaultProfile() }
        let browserShellIsVisible = await MainActor.run { browser?.isVisible() ?? false }

        XCTAssertNotNil(browser)
        XCTAssertTrue(browserShellIsVisible)
    }
}
