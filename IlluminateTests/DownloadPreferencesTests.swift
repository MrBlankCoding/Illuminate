//
//  DownloadPreferencesTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Testing
@testable import Illuminate

struct DownloadPreferencesTests {
    @Test func supportsDefaultsAndCustomValues() {
        let defaults = DownloadPreferences()
        #expect(defaults.revealInFinderWhenFinished == false)
        #expect(defaults.saveLocationBookmarkData == nil)
        #expect(defaults.askWhereToSave == false)
        #expect(defaults.lastPickedDirectoryBookmarkData == nil)

        let data = Data([1, 2, 3])
        let custom = DownloadPreferences(
            revealInFinderWhenFinished: true,
            saveLocationBookmarkData: data,
            askWhereToSave: true,
            lastPickedDirectoryBookmarkData: data
        )
        #expect(custom.revealInFinderWhenFinished == true)
        #expect(custom.saveLocationBookmarkData == data)
        #expect(custom.askWhereToSave == true)
        #expect(custom.lastPickedDirectoryBookmarkData == data)
    }
}
