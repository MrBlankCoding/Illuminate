//
//  TrackerBlockingBehaviorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TrackerBlockingBehaviorTests {
    private func makeService() -> TrackerBlockingService {
        TrackerBlockingService(
            profileID: UUID(),
            isPersistenceEnabled: false,
            userDefaults: UserDefaults(suiteName: "tracker-tests.\(UUID().uuidString)")!
        )
    }

    @Test func learnedDomainBecomesBlockedAtThreshold() {
        let service = makeService()
        service.learnThreshold = 2

        service.record(thirdPartyDomain: "tracker.example", seenOn: "one.example")
        service.record(thirdPartyDomain: "TRACKER.EXAMPLE", seenOn: "two.example")
        service.flushPendingUpdates()

        let stat = service.domainStats.first { $0.domain == "tracker.example" }
        #expect(stat?.firstPartyCount == 2)
        #expect(stat?.isBlocked == true)
        #expect(stat?.override == nil)
    }

    @Test func allowAndBlockOverridesTakePrecedenceOverLearnedState() {
        let service = makeService()
        service.learnThreshold = 1
        service.record(thirdPartyDomain: "tracker.example", seenOn: "site.example")
        service.allow(domain: "TRACKER.EXAMPLE")
        service.flushPendingUpdates()

        #expect(service.domainStats.first?.isBlocked == false)
        #expect(service.domainStats.first?.override == .allowed)

        service.block(domain: "tracker.example")
        service.flushPendingUpdates()

        #expect(service.domainStats.first?.isBlocked == true)
        #expect(service.domainStats.first?.override == .blocked)
    }

    @Test func invalidAndSameOriginObservationsAreIgnored() {
        let service = makeService()

        service.record(thirdPartyDomain: "", seenOn: "site.example")
        service.record(thirdPartyDomain: "tracker.example", seenOn: "")
        service.record(thirdPartyDomain: "site.example", seenOn: "site.example")
        service.record(thirdPartyDomain: "google.com", seenOn: "site.example")
        service.flushPendingUpdates()

        #expect(service.domainStats.isEmpty)
    }
}
