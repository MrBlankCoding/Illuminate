//
//  WindowDeepLinkRoutingTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct WindowDeepLinkRoutingTests {
    @Test func deepLinkRejectsNonIlluminateScheme() {
        let request = BrowserWindowOpenRequest(url: URL(string: "https://new")!)

        #expect(request == nil)
    }

    @Test func deepLinkAcceptsCaseInsensitiveNewHost() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://NEW")!)

        #expect(request == .profileSelection)
    }

    @Test func profileDeepLinkRequiresProfileIdentifier() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile")!)

        #expect(request == nil)
    }

    @Test func profileDeepLinkRejectsEmptyProfileIdentifier() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile/")!)

        #expect(request == nil)
    }

    @Test func profileDeepLinkUsesFirstPathComponent() {
        let id = UUID()
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile/\(id.uuidString)/extra")!)

        #expect(request == .route(.profile(id)))
    }

    @Test func guestDeepLinkCreatesGuestRoute() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://guest")!)

        guard case let .route(.guest(id))? = request else {
            Issue.record("Expected a guest route")
            return
        }
        #expect(id.uuidString.isEmpty == false)
    }

    @Test func profileAndGuestRoutesWithSameIdentifierAreDistinct() {
        let id = UUID()

        #expect(BrowserWindowRoute.profile(id) != .guest(id))
    }

    @Test func matchingRoutesAreEqualAndHashable() {
        let id = UUID()
        let routes: Set<BrowserWindowRoute> = [.profile(id), .profile(id), .guest(id), .guest(id)]

        #expect(routes.count == 2)
        #expect(BrowserWindowRoute.profile(id) == .profile(id))
        #expect(BrowserWindowRoute.guest(id) == .guest(id))
    }
}
