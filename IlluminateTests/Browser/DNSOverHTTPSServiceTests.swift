//
//  DNSOverHTTPSServiceTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
@testable import Illuminate

struct DNSOverHTTPSServiceTests {

    private let service = DNSOverHTTPSService.shared

    @Test("http and https are always allowed")
    func httpAndHttpsAllowed() {
        #expect(service.shouldAllowRequest(for: URL(string: "http://example.com")!) == true)
        #expect(service.shouldAllowRequest(for: URL(string: "https://example.com")!) == true)
        #expect(service.shouldAllowRequest(for: URL(string: "https://example.com/path?q=1")!) == true)
    }

    @Test("about:blank is allowed so blank loads don't get blocked")
    func aboutBlankAllowed() {
        #expect(service.shouldAllowRequest(for: URL(string: "about:blank")!) == true)
    }

    @Test("webkit-extension URLs are allowed so installed extensions load")
    func webkitExtensionAllowed() {
        let url = URL(string: "webkit-extension://abcdef-uuid/dashboard/dashboard.html")!
        #expect(service.shouldAllowRequest(for: url) == true)
    }

    @Test("illuminate internal pages are allowed for in-app navigation")
    func illuminateAllowed() {
        let cases: [String] = [
            "illuminate://passwords",
            "illuminate://history",
            "illuminate://downloads",
            "illuminate://protection",
            "illuminate://permissions",
            "illuminate://info",
            "illuminate://extensions",
            "illuminate://new",
            "illuminate://profile/abc",
        ]
        for raw in cases {
            let url = URL(string: raw)!
            #expect(service.shouldAllowRequest(for: url) == true, "Expected allow for \(raw)")
        }
    }

    @Test("unsupported schemes are blocked")
    func unsupportedSchemesBlocked() {
        let blocked: [String] = [
            "ftp://example.com/file.txt",
            "file:///etc/passwd",
            "data:text/plain,hello",
            "blob:https://example.com/uuid",
            "javascript:alert(1)",
            "ws://example.com/socket",
            "wss://example.com/socket",
            "mailto:user@example.com",
        ]
        for raw in blocked {
            let url = URL(string: raw)!
            #expect(service.shouldAllowRequest(for: url) == false, "Expected block for \(raw)")
        }
    }

    @Test("scheme comparison is case insensitive")
    func schemeCaseInsensitive() {
        #expect(service.shouldAllowRequest(for: URL(string: "HTTPS://example.com")!) == true)
        #expect(service.shouldAllowRequest(for: URL(string: "ILLUMINATE://passwords")!) == true)
        #expect(service.shouldAllowRequest(for: URL(string: "WebKit-Extension://x/y")!) == true)
    }

    @Test("URLs without a scheme are blocked")
    func schemelessBlocked() {
        let url = URL(string: "example.com/path")!
        #expect(service.shouldAllowRequest(for: url) == false)
    }

    @Test("nil scheme is blocked")
    func nilSchemeBlocked() {
        var components = URLComponents()
        components.host = "example.com"
        components.path = "/x"
        let url = components.url!
        #expect(url.scheme == nil)
        #expect(service.shouldAllowRequest(for: url) == false)
    }
}
