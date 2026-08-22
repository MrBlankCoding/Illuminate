//
//  CaptchaCompatibility.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import Foundation

enum CaptchaCompatibility {
    static let providerDomains: Set<String> = [
        "arkoselabs.com",
        "captcha.com",
        "challenges.cloudflare.com",
        "cloudflare.com",
        "friendlycaptcha.com",
        "funcaptcha.com",
        "google.com",
        "hcaptcha.com",
        "recaptcha.net"
    ]

    static func isProviderHost(_ host: String?) -> Bool {
        guard let normalizedHost = host?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !normalizedHost.isEmpty
        else {
            return false
        }

        return providerDomains.contains { domain in
            normalizedHost == domain || normalizedHost.hasSuffix(".\(domain)")
        }
    }
}
