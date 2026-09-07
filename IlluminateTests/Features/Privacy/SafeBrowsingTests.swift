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

    @Test("subdomain of blocked host is not blocked")
    func subdomainNotBlocked() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://safe.malware.test/")!) == false)
    }

    @Test("URL with port on blocked host is still blocked")
    func portDoesNotBypass() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://malware.test:8443/")!) == true)
    }

    @Test("URL with path on blocked host is blocked regardless of path")
    func pathDoesNotBypass() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://malware.test/anything/here")!) == true)
    }

    @Test("URL with query on blocked host is blocked")
    func queryDoesNotBypass() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://malware.test/?x=1")!) == true)
    }

    @Test("URL with nil host is not blocked")
    func nilHostNotBlocked() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "about:blank")!) == false)
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "data:text/plain,hello")!) == false)
    }

    @Test("scheme variations on blocked host are still blocked")
    func schemeDoesNotBypass() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "http://malware.test")!) == true)
    }
}
