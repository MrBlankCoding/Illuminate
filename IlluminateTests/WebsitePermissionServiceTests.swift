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

    @Test func permissionTypesExposeStablePresentationMetadata() {
        #expect(WebsitePermissionType.camera.id == "camera")
        #expect(WebsitePermissionType.camera.title == "Camera")
        #expect(WebsitePermissionType.camera.icon == "video.fill")
        #expect(WebsitePermissionType.microphone.id == "microphone")
        #expect(WebsitePermissionType.microphone.title == "Microphone")
        #expect(WebsitePermissionType.microphone.icon == "mic.fill")
        #expect(WebsitePermissionType.location.id == "location")
        #expect(WebsitePermissionType.location.title == "Location")
        #expect(WebsitePermissionType.location.icon == "location.fill")
    }

    @Test func unknownPermissionDefaultsToPrompt() {
        let service = WebsitePermissionService(profileID: nil, persists: false)

        #expect(service.decision(for: "https://unknown.example", type: .camera) == .prompt)
    }

    @Test func allPreviouslyAllowedPermissionsCompleteImmediately() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        let origin = "https://allowed.example"
        var result: WebsitePermissionDecision?
        service.set(.allow, for: origin, type: .camera)
        service.set(.allow, for: origin, type: .microphone)

        service.requestPermission(for: origin, types: [.camera, .microphone]) { result = $0 }

        #expect(result == .allow)
        #expect(service.pendingRequest == nil)
    }

    @Test func previouslyDeniedPermissionDeniesMixedRequestImmediately() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        let origin = "https://denied.example"
        var result: WebsitePermissionDecision?
        service.set(.allow, for: origin, type: .camera)
        service.set(.deny, for: origin, type: .microphone)

        service.requestPermission(for: origin, types: [.camera, .microphone]) { result = $0 }

        #expect(result == .deny)
        #expect(service.pendingRequest == nil)
    }

    @Test func emptyPermissionRequestCompletesAsAllowed() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        var result: WebsitePermissionDecision?

        service.requestPermission(for: "https://empty.example", types: []) { result = $0 }

        #expect(result == .allow)
        #expect(service.pendingRequest == nil)
    }

    @Test func allowingPendingRequestPersistsAllRequestedCapabilities() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        let origin = "https://video.example"
        var result: WebsitePermissionDecision?
        service.requestPermission(for: origin, types: [.camera, .microphone]) { result = $0 }

        service.resolvePendingRequest(as: .allow)

        #expect(result == .allow)
        #expect(service.decision(for: origin, type: .camera) == .allow)
        #expect(service.decision(for: origin, type: .microphone) == .allow)
        #expect(service.pendingRequest == nil)
    }

    @Test func resolvingWithoutPendingRequestIsNoOp() {
        let service = WebsitePermissionService(profileID: nil, persists: false)

        service.resolvePendingRequest(as: .allow)

        #expect(service.pendingRequest == nil)
        #expect(service.sites.isEmpty)
    }

    @Test func settingPromptRemovesOnlyThatPermissionType() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        let origin = "https://partial.example"
        service.set(.allow, for: origin, type: .camera)
        service.set(.deny, for: origin, type: .microphone)

        service.set(.prompt, for: origin, type: .camera)

        #expect(service.decision(for: origin, type: .camera) == .prompt)
        #expect(service.decision(for: origin, type: .microphone) == .deny)
        #expect(service.sites.count == 1)
    }

    @Test func removingFinalPermissionRemovesSite() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        let origin = "https://remove.example"
        service.set(.allow, for: origin, type: .location)

        service.set(.prompt, for: origin, type: .location)

        #expect(service.sites.isEmpty)
    }

    @Test func clearingOneOriginPreservesOtherOrigins() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        service.set(.allow, for: "https://one.example", type: .camera)
        service.set(.deny, for: "https://two.example", type: .location)

        service.clearPermissions(for: "https://one.example")

        #expect(service.decision(for: "https://one.example", type: .camera) == .prompt)
        #expect(service.decision(for: "https://two.example", type: .location) == .deny)
    }

    @Test func sitesAreSortedByOrigin() {
        let service = WebsitePermissionService(profileID: nil, persists: false)
        service.set(.allow, for: "https://zeta.example", type: .camera)
        service.set(.allow, for: "https://alpha.example", type: .camera)

        #expect(service.sites.map(\.origin) == ["https://alpha.example", "https://zeta.example"])
    }

    @Test func persistedPermissionsIgnoreUnknownCapabilityKeys() throws {
        let suiteName = "WebsitePermissionServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let profileID = UUID()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "profile.\(profileID.uuidString).websitePermissions"
        let payload: [String: [String: WebsitePermissionDecision]] = [
            "https://stored.example": ["camera": .allow, "unknown": .deny]
        ]
        defaults.set(try JSONEncoder().encode(payload), forKey: key)

        let service = WebsitePermissionService(profileID: profileID, userDefaults: defaults, persists: true)

        #expect(service.decision(for: "https://stored.example", type: .camera) == .allow)
        #expect(service.sites.first?.decisions.count == 1)
    }

    @Test func persistedPermissionsAreIsolatedByProfile() {
        let suiteName = "WebsitePermissionServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let origin = "https://isolated.example"
        let firstProfile = UUID()
        let secondProfile = UUID()
        WebsitePermissionService(profileID: firstProfile, userDefaults: defaults, persists: true)
            .set(.allow, for: origin, type: .camera)

        let secondService = WebsitePermissionService(profileID: secondProfile, userDefaults: defaults, persists: true)

        #expect(secondService.decision(for: origin, type: .camera) == .prompt)
    }
}
