//
//  SafeBrowsingTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct SafeBrowsingTests {
        @Test func safeBrowsingBlocksKnownHostsOnly() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://malware.test/path")!) == true)
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://PHISHING.TEST")!) == true)
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://example.com")!) == false)
        #expect(SafeBrowsingManager.isUnsafe(URL(fileURLWithPath: "/tmp/file")) == false)
    }
}
