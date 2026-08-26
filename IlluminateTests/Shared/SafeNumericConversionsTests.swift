//
//  SafeNumericConversionsTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Illuminate

struct SafeNumericConversionsTests {
        @Test func safeNumericConversionsUseFallbackForInvalidValues() {
        #expect(SafeNumericConversions.int(from: 1.6) == 2)
        #expect(SafeNumericConversions.int(from: .infinity, fallback: 9) == 9)
        #expect(SafeNumericConversions.cgFloat(from: .nan, fallback: 7) == 7)

        let size = SafeNumericConversions.cgSize(width: 10, height: 5)
        #expect(size == CGSize(width: 10, height: 5))

        let fallback = CGSize(width: 3, height: 4)
        #expect(SafeNumericConversions.cgSize(width: .nan, height: 1, fallback: fallback) == fallback)
    }
}
