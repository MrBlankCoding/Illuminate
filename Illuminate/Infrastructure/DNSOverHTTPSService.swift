//
//  DNSOverHTTPSService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation

final class DNSOverHTTPSService {
    static let shared = DNSOverHTTPSService()

    private init() {}

    // Placeholder phase integration point for DoH policies.
    // I know shit about DNS
    func shouldAllowRequest(for url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https" || scheme == "about"
    }
}
