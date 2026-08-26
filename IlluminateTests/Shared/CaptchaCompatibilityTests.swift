//
//  CaptchaCompatibilityTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Testing
import Foundation
@testable import Illuminate

struct CaptchaCompatibilityTests {

    @Test func matchesProviderDomainsExactlyAndBySubdomain() {
        #expect(CaptchaCompatibility.isProviderHost("challenges.cloudflare.com"))
        #expect(CaptchaCompatibility.isProviderHost("www.google.com"))
        #expect(CaptchaCompatibility.isProviderHost("recaptcha.net"))
        #expect(CaptchaCompatibility.isProviderHost("api.hcaptcha.com"))
    }

    @Test func normalizesCaseAndWhitespace() {
        #expect(CaptchaCompatibility.isProviderHost("  CHALLENGES.CloudFlare.COM "))
        #expect(CaptchaCompatibility.isProviderHost("HCAPTCHA.COM"))
    }

    @Test func rejectsNonProvidersAndLookalikes() {
        #expect(!CaptchaCompatibility.isProviderHost("example.com"))
        #expect(!CaptchaCompatibility.isProviderHost("notcloudflare.com"))
        // Suffix match requires a dot boundary, so partial overlaps fail.
        #expect(!CaptchaCompatibility.isProviderHost("evildomain.google.com.evil.io"))
        #expect(!CaptchaCompatibility.isProviderHost(nil))
        #expect(!CaptchaCompatibility.isProviderHost(""))
        #expect(!CaptchaCompatibility.isProviderHost("   "))
    }
}
