//
//  URLSynchronizerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct URLSynchronizerTests {
    @Test func urlSynchronizerPublishesUpdatedURL() async throws {
        let synchronizer = URLSynchronizer()
        let firstURL = URL(string: "https://first.example")!
        let secondURL = URL(string: "https://second.example")!

        synchronizer.updateCurrentURL(nil)
        synchronizer.updateCurrentURL(firstURL)
        #expect(synchronizer.currentURL == firstURL)

        synchronizer.updateCurrentURL(secondURL)
        #expect(synchronizer.currentURL == secondURL)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
