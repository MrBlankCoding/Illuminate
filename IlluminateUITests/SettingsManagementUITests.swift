//
//  SettingsManagementUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class SettingsManagementUITests: IlluminateUITestCase {
    func testOpenSettingsShortcutUpdatesAddressBar() async {
        await launchApp(resetState: true)

        let browser = await MainActor.run { uiTestApp.profileSelection.openDefaultProfile() }
        XCTAssertNotNil(browser)

        let didUpdateURLBar = await MainActor.run { () -> Bool in
            guard let browser else { return false }
            browser.openSettingsWithShortcut()
            return browser.waitForURLBarValue("illuminate://settings")
        }
        XCTAssertTrue(didUpdateURLBar)
    }
}
