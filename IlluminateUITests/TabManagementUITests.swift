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

        let browser = await uiTestApp.profileSelection.openDefaultProfile()
        XCTAssertNotNil(browser)

        await browser?.navigateToAddress("example.com")
        let didResolveToHTTPS = await browser?.waitForURLBarValue(containing: "https://example.com")
        XCTAssertTrue(didResolveToHTTPS ?? false)
    }

    func testAddressBarRoutesSearchQueriesToGoogle() async {
        await launchApp(resetState: true)

        let browser = await uiTestApp.profileSelection.openDefaultProfile()
        XCTAssertNotNil(browser)

        await browser?.navigateToAddress("swift ui testing")
        let didRouteToGoogle = await browser?.waitForURLBarValue(containing: "https://www.google.com/search?q=swift%20ui%20testing")
        XCTAssertTrue(didRouteToGoogle ?? false)
    }
}
