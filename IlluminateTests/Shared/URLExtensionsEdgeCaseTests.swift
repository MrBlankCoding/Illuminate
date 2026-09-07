//
//  URLExtensionsEdgeCaseTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
@testable import Illuminate

struct URLExtensionsEdgeCaseTests {

    @Test("plain domain returns the domain")
    func plainDomain() {
        #expect(URL(string: "https://example.com/")!.eTLDPlusOne == "example.com")
    }

    @Test("subdomain returns the registrable domain")
    func subdomain() {
        #expect(URL(string: "https://a.b.example.com/")!.eTLDPlusOne == "example.com")
        #expect(URL(string: "https://www.bbc.co.uk/news")!.eTLDPlusOne == "bbc.co.uk")
    }

    @Test("multi-part TLDs are recognized")
    func multiPartTLDs() {
        let cases: [(String, String)] = [
            ("https://example.co.uk/x", "example.co.uk"),
            ("https://www.example.co.uk/x", "example.co.uk"),
            ("https://shop.example.co.jp/p", "example.co.jp"),
            ("https://www.shop.example.org.au/p", "example.org.au"),
        ]
        for (raw, expected) in cases {
            let url = URL(string: raw)!
            #expect(url.eTLDPlusOne == expected, "URL \(raw) should resolve to \(expected)")
        }
    }

    @Test("IPv4 address is returned as-is")
    func ipv4() {
        #expect(URL(string: "http://127.0.0.1/x")!.eTLDPlusOne == "127.0.0.1")
        #expect(URL(string: "http://192.168.1.1:8080/x")!.eTLDPlusOne == "192.168.1.1")
    }

    @Test("out-of-range IPv4 octets are not treated as IPs")
    func invalidIPv4() {
        #expect(URL(string: "http://999.0.0.1/x")!.eTLDPlusOne != "999.0.0.1")
    }

    @Test("IPv6 literal is returned as-is")
    func ipv6() {
        let url = URL(string: "https://[2001:db8::1]/x")!
        #expect(url.eTLDPlusOne == "2001:db8::1")
    }

    @Test("localhost returns localhost")
    func localhost() {
        #expect(URL(string: "http://localhost/x")!.eTLDPlusOne == "localhost")
    }

    @Test("single-label host returns the host itself")
    func singleLabel() {
        #expect(URL(string: "http://intranet/x")!.eTLDPlusOne == "intranet")
    }

    @Test("empty host returns nil")
    func emptyHost() {
        #expect(URL(string: "file:///etc/hosts")!.eTLDPlusOne == nil)
    }

    @Test("host with port is treated like host")
    func hostWithPort() {
        #expect(URL(string: "https://example.com:8443/x")!.eTLDPlusOne == "example.com")
    }
}
