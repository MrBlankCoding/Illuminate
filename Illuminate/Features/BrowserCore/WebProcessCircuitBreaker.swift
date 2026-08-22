//
//  WebProcessCircuitBreaker.swift
//  Illuminate
//
//  Created by MrBkankCoding on 3/8/26.
//


import Foundation

final class WebProcessCircuitBreaker {
    private let maxReloads: Int
    private let cooldown: TimeInterval
    private var timestamps: [Date] = []

    init(maxReloads: Int = 2, cooldown: TimeInterval = 60) {
        self.maxReloads = maxReloads
        self.cooldown = cooldown
    }

    func canReloadAfterTermination() -> Bool {
        let now = Date()
        timestamps = timestamps.filter { now.timeIntervalSince($0) < cooldown }

        guard timestamps.count < maxReloads else {
            return false
        }

        timestamps.append(now)
        return true
    }

    func reset() {
        timestamps.removeAll()
    }
}
