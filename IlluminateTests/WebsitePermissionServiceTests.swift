//
//  WebsitePermissionServiceTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct WebsitePermissionServiceTests {
    @Test func previouslyAllowedPermissionCompletesWithoutShowingAnotherPrompt() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        let origin = "https://meet.example"
        var completionDecision: WebsitePermissionDecision?
        service.set(.allow, for: origin, type: .camera)

        service.requestPermission(for: origin, types: [.camera]) { decision in
            completionDecision = decision
        }

        #expect(completionDecision?.rawValue == WebsitePermissionDecision.allow.rawValue)
        #expect(service.pendingRequest == nil)
    }

    @Test func resolvingCombinedPromptRecordsDecisionForEveryRequestedCapability() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        let origin = "https://call.example"
        var completionDecision: WebsitePermissionDecision?

        service.requestPermission(for: origin, types: [.camera, .microphone]) { decision in
            completionDecision = decision
        }
        let pendingRequest = try! #require(service.pendingRequest)
        #expect(pendingRequest.origin == origin)
        #expect(pendingRequest.types.count == 2)

        service.resolvePendingRequest(as: .deny)

        #expect(completionDecision?.rawValue == WebsitePermissionDecision.deny.rawValue)
        #expect(service.decision(for: origin, type: .camera).rawValue == WebsitePermissionDecision.deny.rawValue)
        #expect(service.decision(for: origin, type: .microphone).rawValue == WebsitePermissionDecision.deny.rawValue)
        #expect(service.pendingRequest == nil)
    }

    @Test func persistedDecisionIsAvailableToTheNextProfileServiceInstance() {
        let suiteName = "WebsitePermissionServiceTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let profileID = UUID()
        let origin = "https://maps.example"
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let savingService = WebsitePermissionService(
            profileID: profileID,
            userDefaults: userDefaults,
            persists: true
        )
        savingService.set(.allow, for: origin, type: .location)

        let reloadedService = WebsitePermissionService(
            profileID: profileID,
            userDefaults: userDefaults,
            persists: true
        )

        #expect(reloadedService.decision(for: origin, type: .location).rawValue == WebsitePermissionDecision.allow.rawValue)
        #expect(reloadedService.sites.count == 1)
        #expect(reloadedService.sites.first?.origin == origin)
    }

    @Test func concurrentPermissionPromptIsDeniedAndCleanupResolvesOriginalRequest() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        var firstDecision: WebsitePermissionDecision?
        var secondDecision: WebsitePermissionDecision?

        service.requestPermission(for: "https://first.example", types: [.camera]) { decision in
            firstDecision = decision
        }
        service.requestPermission(for: "https://second.example", types: [.microphone]) { decision in
            secondDecision = decision
        }

        #expect(secondDecision?.rawValue == WebsitePermissionDecision.deny.rawValue)
        #expect(service.pendingRequest?.origin == "https://first.example")

        service.prepareForRemoval()

        #expect(firstDecision?.rawValue == WebsitePermissionDecision.deny.rawValue)
        #expect(service.pendingRequest == nil)
    }
}
