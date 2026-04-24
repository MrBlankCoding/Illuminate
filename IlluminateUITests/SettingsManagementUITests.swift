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

        let browser = await uiTestApp.profileSelection.openDefaultProfile()
        XCTAssertNotNil(browser)

        await browser?.openSettingsWithShortcut()
        let didUpdateURLBar = await browser?.waitForURLBarValue("illuminate://settings")
        XCTAssertTrue(didUpdateURLBar ?? false)
    }
}
