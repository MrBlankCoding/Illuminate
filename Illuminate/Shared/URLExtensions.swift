//
//  URLExtensions.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/10/26.
//

import Foundation

extension URL {
    nonisolated var eTLDPlusOne: String? {
        guard let host = self.host?.lowercased(), !host.isEmpty else { return nil }

        if host.hasPrefix("[") {
            return host
        }

        // IPv6 literals contain colons and have no registrable-domain concept.
        if host.contains(":") {
            return host
        }

        let bare = host.components(separatedBy: ":").first ?? host

        if isIPv4Address(bare) {
            return bare
        }

        let labels = bare.components(separatedBy: ".")
        guard labels.count >= 2 else { return bare }

        // need a better solution than just hard coding
        let twoPartTLDs: Set<String> = [
            "co.uk", "co.nz", "co.jp", "co.in", "co.za", "co.kr",
            "com.au", "com.br", "com.mx", "com.ar", "com.sg", "com.hk",
            "org.uk", "org.au", "net.au", "gov.uk", "ac.uk",
            "ne.jp", "or.jp", "go.jp", "ac.jp"
        ]

        if labels.count >= 3 {
            let candidate = labels.suffix(2).joined(separator: ".")
            if twoPartTLDs.contains(candidate) {
                return labels.suffix(3).joined(separator: ".")
            }
        }

        return labels.suffix(2).joined(separator: ".")
    }

    private nonisolated func isIPv4Address(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return value >= 0 && value <= 255
        }
    }
}
