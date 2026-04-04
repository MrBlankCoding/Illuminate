//
//  TabManagementUITests.swift
//  IlluminateUITests
//
//  Created by MrBlankCoding on 3/8/26.
//

import XCTest

final class TabManagementUITests: IlluminateUITestCase {
    func testAddressBarResolvesWebAddressToHTTPS() async {
        await launchApp(resetState: true)

        let browser = await MainActor.run { uiTestApp.profileSelection.openDefaultProfile() }
        XCTAssertNotNil(browser)

        let didResolveToHTTPS = await MainActor.run { () -> Bool in
            guard let browser else { return false }
            browser.navigateToAddress("example.com")
            return browser.waitForURLBarValue(containing: "https://example.com")
        }
        XCTAssertTrue(didResolveToHTTPS)
    }

    func testAddressBarRoutesSearchQueriesToGoogle() async {
        await launchApp(resetState: true)

        let browser = await MainActor.run { uiTestApp.profileSelection.openDefaultProfile() }
        XCTAssertNotNil(browser)

        let didRouteToGoogle = await MainActor.run { () -> Bool in
            guard let browser else { return false }
            browser.navigateToAddress("swift ui testing")
            return browser.waitForURLBarValue(containing: "https://www.google.com/search?q=swift%20ui%20testing")
        }
        XCTAssertTrue(didRouteToGoogle)
    }
}
