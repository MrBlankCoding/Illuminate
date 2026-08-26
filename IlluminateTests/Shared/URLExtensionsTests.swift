//
//  URLExtensionsTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct URLExtensionsTests {

    @Test func standardDomainsReturnTwoLabelSuffix() {
        #expect(URL(string: "https://example.com")!.eTLDPlusOne == "example.com")
        #expect(URL(string: "https://a.b.example.org/page")!.eTLDPlusOne == "example.org")
        #expect(URL(string: "https://localhost/x")!.eTLDPlusOne == "localhost")
    }

    @Test func twoPartTLDsKeepThreeLabels() {
        #expect(URL(string: "https://www.bbc.co.uk/news")!.eTLDPlusOne == "bbc.co.uk")
        #expect(URL(string: "https://shop.com.au")!.eTLDPlusOne == "shop.com.au")
        #expect(URL(string: "https://deep.site.org.uk/")!.eTLDPlusOne == "site.org.uk")
        #expect(URL(string: "https://sub.ac.jp")!.eTLDPlusOne == "sub.ac.jp")
    }

    @Test func nonListedSecondLevelDomainsCollapse() {
        // .com.br is listed but .example.br is not a known two-part TLD.
        #expect(URL(string: "https://a.b.example.br")!.eTLDPlusOne == "example.br")
        #expect(URL(string: "https://x.y.z.dev")!.eTLDPlusOne == "z.dev")
    }

    @Test func ipv4HostsAreReturnedWhole() {
        #expect(URL(string: "http://192.168.0.1/admin")!.eTLDPlusOne == "192.168.0.1")
        #expect(URL(string: "http://10.0.0.255:8080/")!.eTLDPlusOne == "10.0.0.255")
        // Not a valid IPv4 (out of range) — falls through to label handling.
        #expect(URL(string: "http://999.1.1.1/")!.eTLDPlusOne == "1.1")
    }

    @Test func ipv6AndPortedHostsAreHandled() {
        #expect(URL(string: "http://[::1]:8080/x")!.eTLDPlusOne == "::1")
        #expect(URL(string: "http://example.com:443")!.eTLDPlusOne == "example.com")
    }

    @Test func hostsWithoutDotsOrEmptyHostFallBackGracefully() {
        #expect(URL(string: "https://singlelabel")!.eTLDPlusOne == "singlelabel")

        // Non-web schemes have no host.
        #expect(URL(string: "mailto:someone@example.com")!.eTLDPlusOne == nil)
        #expect(URL(fileURLWithPath: "/tmp/x").eTLDPlusOne == nil)
    }
}
