//
//  SecurityScopedAccess.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/20/26.
//

import Foundation

extension URL {
    func withSecurityScopedAccess<T>(_ block: () throws -> T) rethrows -> T {
        let isSecured = startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                stopAccessingSecurityScopedResource()
            }
        }
        return try block()
    }
}
