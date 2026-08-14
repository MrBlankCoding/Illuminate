//
//  SafeNumericConversions.swift
//  Illuminate
//
//  Created by Ethan Hall on 8/13/26.
//


import CoreGraphics
import Foundation

enum SafeNumericConversions {
    static func int(from value: Double, fallback: Int = 0) -> Int {
        guard value.isFinite, value >= Double(Int.min), value <= Double(Int.max) else {
            return fallback
        }
        return Int(value.rounded())
    }

    static func cgFloat(from value: Double, fallback: CGFloat = 0) -> CGFloat {
        guard value.isFinite else {
            return fallback
        }
        return CGFloat(value)
    }

    static func cgSize(width: Double, height: Double, fallback: CGSize = .zero) -> CGSize {
        guard width.isFinite, height.isFinite else {
            return fallback
        }
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }
}
