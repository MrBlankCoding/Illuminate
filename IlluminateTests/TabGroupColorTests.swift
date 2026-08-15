//
//  TabGroupColorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Testing
@testable import Illuminate

struct TabGroupColorTests {
    @MainActor @Test func exposesIdentityAndPresentation() {
        #expect(TabGroupColor.allCases.count == 8)
        #expect(TabGroupColor.blue.id == "blue")
        #expect(TabGroupColor.purple.displayName == "Purple")
        for color in TabGroupColor.allCases { _ = color.color }
    }
}
