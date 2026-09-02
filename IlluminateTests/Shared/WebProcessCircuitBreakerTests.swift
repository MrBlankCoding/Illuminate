//
//  WebProcessCircuitBreakerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct WebProcessCircuitBreakerTests {
        @Test func circuitBreakerStopsAfterConfiguredBurstAndResets() {
        let breaker = WebProcessCircuitBreaker(maxReloads: 2, cooldown: 60)

        #expect(breaker.canReloadAfterTermination() == true)
        #expect(breaker.canReloadAfterTermination() == true)
        #expect(breaker.canReloadAfterTermination() == false)

        breaker.reset()

        #expect(breaker.canReloadAfterTermination() == true)
    }

    @Test func zeroCooldownAllowsASecondAttemptAfterTheFirstExpires() {
        let breaker = WebProcessCircuitBreaker(maxReloads: 1, cooldown: 0)

        #expect(breaker.canReloadAfterTermination())
        #expect(breaker.canReloadAfterTermination())
    }

    @Test func resetClearsEveryRecordedReload() {
        let breaker = WebProcessCircuitBreaker(maxReloads: 1, cooldown: 60)

        #expect(breaker.canReloadAfterTermination())
        #expect(!breaker.canReloadAfterTermination())
        breaker.reset()

        #expect(breaker.canReloadAfterTermination())
        #expect(!breaker.canReloadAfterTermination())
    }

    @Test func singleReloadLimitRejectsFurtherAttemptsWithinCooldown() {
        let breaker = WebProcessCircuitBreaker(maxReloads: 1, cooldown: 60)

        #expect(breaker.canReloadAfterTermination())
        #expect(!breaker.canReloadAfterTermination())
        #expect(!breaker.canReloadAfterTermination())
    }
}
