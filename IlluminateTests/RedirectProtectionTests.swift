//
//  RedirectProtectionTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 4/4/26.
//

import Foundation
import Testing
@testable import Illuminate

@Suite(.serialized)
@MainActor
struct RedirectProtectionTests {

    @Test func testBlocksCrossOriginServerRedirects() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/page")!
        let target = URL(string: "https://malicious-site.com/phish")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == true)
    }

    @Test func testAllowsSameHostRedirects() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/page-a")!
        let target = URL(string: "https://example.com/page-b")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsSameOriginDifferentPathRedirects() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://shop.example.com/cart")!
        let target = URL(string: "https://shop.example.com/checkout")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsSubdomainRedirectsWithinSameSite() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://app.example.com/dashboard")!
        let target = URL(string: "https://api.example.com/auth")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testBlocksRedirectsToDifferentSite() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://login.example.com/auth")!
        let target = URL(string: "https://tracking.adnetwork.com/pixel")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == true)
    }

    @Test func testEffectiveSiteExtraction() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        #expect(service.effectiveSite(for: URL(string: "https://mail.google.com")!) == "google.com")
        #expect(service.effectiveSite(for: URL(string: "https://www.example.com")!) == "example.com")
        #expect(service.effectiveSite(for: URL(string: "https://a.b.c.example.com")!) == "example.com")
        #expect(service.effectiveSite(for: URL(string: "https://www.example.co.uk")!) == "example.co.uk")
        #expect(service.effectiveSite(for: URL(string: "https://shop.example.com.au")!) == "example.com.au")
        #expect(service.effectiveSite(for: URL(string: "https://example.com")!) == "example.com")
    }

    @Test func testEffectiveSiteForIPAddresses() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)

        #expect(service.effectiveSite(for: URL(string: "http://192.168.1.1/admin")!) == "192.168.1.1")
        #expect(service.effectiveSite(for: URL(string: "http://127.0.0.1:8080")!) == "127.0.0.1")
    }

    @Test func testEffectiveSiteForLocalhost() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        #expect(service.effectiveSite(for: URL(string: "http://localhost:3000")!) == "localhost")
    }

    @Test func testAllowsOAuthRedirectsToGoogle() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://myapp.com/login")!
        let target = URL(string: "https://accounts.google.com/o/oauth2/auth")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsStripeCheckoutRedirects() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://shop.example.com/cart")!
        let target = URL(string: "https://checkout.stripe.com/pay/cs_test_123")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsRedirectsFromWellKnownProviders() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true
        let source = URL(string: "https://accounts.google.com/o/oauth2/callback")!
        let target = URL(string: "https://myapp.com/auth/callback")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsWhenDisabled() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = false

        let source = URL(string: "https://example.com/page")!
        let target = URL(string: "https://evil.com/page")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsWhenSourceURLIsNil() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let target = URL(string: "https://somewhere.com/page")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: nil, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsAboutBlankSourceNavigation() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "about:blank")!
        let target = URL(string: "https://example.com/page")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testAllowsAboutBlankTargetNavigation() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/page")!
        let target = URL(string: "about:blank")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: false
        ) == false)
    }

    @Test func testAllowsBlobNavigation() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/page")!
        let target = URL(string: "blob:https://example.com/1234-5678")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: false
        ) == false)
    }

    @Test func testAllowsHTTPToHTTPSUpgrade() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "http://example.com/page")!
        let target = URL(string: "https://example.com/page")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testSingleClientSideRedirectIsAllowed() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 2, chainTimeWindow: 2.0
        )
        service.isEnabled = true

        let source = URL(string: "https://example.com/page")!
        let target = URL(string: "https://tracker.com/bounce")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: false
        ) == false)
    }

    @Test func testRapidClientSideChainIsBlocked() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 2, chainTimeWindow: 2.0
        )
        service.isEnabled = true
        let tabID = UUID()

        let now = Date()

        _ = service.shouldBlockNavigation(
            from: URL(string: "https://example.com")!,
            to: URL(string: "https://tracker1.com")!,
            tabID: tabID,
            isServerRedirect: false,
            now: now
        )

        let blocked = service.shouldBlockNavigation(
            from: URL(string: "https://tracker1.com")!,
            to: URL(string: "https://tracker2.com")!,
            tabID: tabID,
            isServerRedirect: false,
            now: now.addingTimeInterval(0.2)
        )

        #expect(blocked == true)
    }

    @Test func testChainResetsAfterTimeWindow() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 2, chainTimeWindow: 1.0
        )
        service.isEnabled = true
        let tabID = UUID()

        let now = Date()

        _ = service.shouldBlockNavigation(
            from: URL(string: "https://example.com")!,
            to: URL(string: "https://tracker1.com")!,
            tabID: tabID,
            isServerRedirect: false,
            now: now
        )

        let blocked = service.shouldBlockNavigation(
            from: URL(string: "https://tracker1.com")!,
            to: URL(string: "https://tracker2.com")!,
            tabID: tabID,
            isServerRedirect: false,
            now: now.addingTimeInterval(2.0)
        )

        #expect(blocked == false)
    }

    @Test func testChainResetsOnUserNavigation() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 2, chainTimeWindow: 5.0
        )
        service.isEnabled = true
        let tabID = UUID()

        _ = service.shouldBlockNavigation(
            from: URL(string: "https://example.com")!,
            to: URL(string: "https://tracker1.com")!,
            tabID: tabID,
            isServerRedirect: false
        )

        service.recordUserNavigation(to: URL(string: "https://tracker1.com")!, tabID: tabID)

        let blocked = service.shouldBlockNavigation(
            from: URL(string: "https://tracker1.com")!,
            to: URL(string: "https://tracker2.com")!,
            tabID: tabID,
            isServerRedirect: false
        )

        #expect(blocked == false)
    }

    @Test func testChainResetsOnCommittedNavigation() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 2, chainTimeWindow: 5.0
        )
        service.isEnabled = true
        let tabID = UUID()

        _ = service.shouldBlockNavigation(
            from: URL(string: "https://example.com")!,
            to: URL(string: "https://tracker1.com")!,
            tabID: tabID,
            isServerRedirect: false
        )

        service.recordCommittedNavigation(to: URL(string: "https://tracker1.com")!, tabID: tabID)

        let blocked = service.shouldBlockNavigation(
            from: URL(string: "https://tracker1.com")!,
            to: URL(string: "https://tracker2.com")!,
            tabID: tabID,
            isServerRedirect: false
        )

        #expect(blocked == false)
    }

    @Test func testServerRedirectBlocksImmediately() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 5, chainTimeWindow: 2.0
        )
        service.isEnabled = true
        let tabID = UUID()

        let blocked = service.shouldBlockNavigation(
            from: URL(string: "https://example.com/page")!,
            to: URL(string: "https://malicious.com/phish")!,
            tabID: tabID,
            isServerRedirect: true
        )

        #expect(blocked == true)
    }

    @Test func testChainsAreIsolatedPerTab() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 2, chainTimeWindow: 5.0
        )
        service.isEnabled = true
        let tab1 = UUID()
        let tab2 = UUID()

        _ = service.shouldBlockNavigation(
            from: URL(string: "https://example.com")!,
            to: URL(string: "https://tracker1.com")!,
            tabID: tab1,
            isServerRedirect: false
        )

        let blocked = service.shouldBlockNavigation(
            from: URL(string: "https://example.com")!,
            to: URL(string: "https://tracker2.com")!,
            tabID: tab2,
            isServerRedirect: false
        )

        #expect(blocked == false)
    }

    @Test func testStableURLTracking() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        let tabID = UUID()

        #expect(service.stableURL(for: tabID) == nil)

        let url = URL(string: "https://example.com")!
        service.recordUserNavigation(to: url, tabID: tabID)
        #expect(service.stableURL(for: tabID) == url)

        let url2 = URL(string: "https://other.com")!
        service.recordCommittedNavigation(to: url2, tabID: tabID)
        #expect(service.stableURL(for: tabID) == url2)
    }

    @Test func testCleanupTab() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        let tabID = UUID()

        service.recordUserNavigation(to: URL(string: "https://example.com")!, tabID: tabID)
        #expect(service.stableURL(for: tabID) != nil)

        service.cleanupTab(tabID)
        #expect(service.stableURL(for: tabID) == nil)
    }

    @Test func testCleanupTabDismissesPromptForThatTab() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        let tabID = UUID()

        service.presentBlockedRedirect(
            tabID: tabID,
            sourceURL: URL(string: "https://a.com")!,
            targetURL: URL(string: "https://b.com")!
        ) {}

        #expect(service.activeBlockedRedirect != nil)

        service.cleanupTab(tabID)
        #expect(service.activeBlockedRedirect == nil)
    }

    @Test func testCleanupTabDoesNotDismissPromptForOtherTab() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        let tab1 = UUID()
        let tab2 = UUID()

        service.presentBlockedRedirect(
            tabID: tab1,
            sourceURL: URL(string: "https://a.com")!,
            targetURL: URL(string: "https://b.com")!
        ) {}

        service.cleanupTab(tab2)
        #expect(service.activeBlockedRedirect != nil)
    }

    @Test func testAllowBlockedRedirectAndProceedAddsRule() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/")!
        let target = URL(string: "https://partner.com/landing")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == true)

        var proceedCalled = false
        service.presentBlockedRedirect(
            tabID: tabID,
            sourceURL: source,
            targetURL: target
        ) {
            proceedCalled = true
        }

        #expect(service.activeBlockedRedirect != nil)

        service.allowBlockedRedirectAndProceed()

        #expect(proceedCalled == true)
        #expect(service.activeBlockedRedirect == nil)
        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
        #expect(service.allowedRedirectRules.count == 1)
    }

    @Test func testProceedWithoutAddingRule() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/")!
        let target = URL(string: "https://ads.com/click")!
        let tabID = UUID()

        var proceedCalled = false
        service.presentBlockedRedirect(
            tabID: tabID,
            sourceURL: source,
            targetURL: target
        ) {
            proceedCalled = true
        }

        service.proceedWithBlockedRedirect()

        #expect(proceedCalled == true)
        #expect(service.activeBlockedRedirect == nil)
        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == true)
    }

    @Test func testDismissPromptClearsPromptWithoutProceeding() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        var proceedCalled = false
        service.presentBlockedRedirect(
            tabID: UUID(),
            sourceURL: URL(string: "https://a.com")!,
            targetURL: URL(string: "https://b.com")!
        ) {
            proceedCalled = true
        }

        #expect(service.activeBlockedRedirect != nil)
        service.dismissPrompt()

        #expect(service.activeBlockedRedirect == nil)
        #expect(proceedCalled == false)
    }

    @Test func testDuplicateAllowRuleIsNotAdded() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/")!
        let target = URL(string: "https://partner.com/")!

        service.presentBlockedRedirect(
            tabID: UUID(),
            sourceURL: source,
            targetURL: target
        ) {}
        service.allowBlockedRedirectAndProceed()

        let countAfterFirst = service.allowedRedirectRules.count
        service.presentBlockedRedirect(
            tabID: UUID(),
            sourceURL: source,
            targetURL: target
        ) {}
        service.allowBlockedRedirectAndProceed()

        #expect(service.allowedRedirectRules.count == countAfterFirst)
    }

    @Test func testRemoveAllowedRedirectRuleByID() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://example.com/")!
        let target = URL(string: "https://partner.com/")!
        let tabID = UUID()

        service.presentBlockedRedirect(
            tabID: tabID,
            sourceURL: source,
            targetURL: target
        ) {}
        service.allowBlockedRedirectAndProceed()

        #expect(service.allowedRedirectRules.count == 1)
        let ruleID = service.allowedRedirectRules[0].id

        service.removeAllowedRedirectRule(id: ruleID)
        #expect(service.allowedRedirectRules.isEmpty)
        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == true)
    }

    @Test func testClearAllAllowedRedirectRules() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let pairs: [(String, String)] = [
            ("https://a.com", "https://b.com"),
            ("https://c.com", "https://d.com"),
            ("https://e.com", "https://f.com"),
        ]

        for (s, t) in pairs {
            service.presentBlockedRedirect(
                tabID: UUID(),
                sourceURL: URL(string: s)!,
                targetURL: URL(string: t)!
            ) {}
            service.allowBlockedRedirectAndProceed()
        }

        #expect(service.allowedRedirectRules.count == 3)

        service.clearAllAllowedRedirectRules()
        #expect(service.allowedRedirectRules.isEmpty)
    }

    @Test func testBlockedRedirectPromptLabels() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://shop.example.com/cart")!
        let target = URL(string: "https://payment.stripe.com/checkout")!

        service.presentBlockedRedirect(
            tabID: UUID(),
            sourceURL: source,
            targetURL: target
        ) {}

        let prompt = service.activeBlockedRedirect!
        #expect(prompt.sourceLabel == "shop.example.com")
        #expect(prompt.targetLabel == "payment.stripe.com")
    }

    @Test func testBlockedRedirectPromptLabelForNilSource() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)

        service.presentBlockedRedirect(
            tabID: UUID(),
            sourceURL: nil,
            targetURL: URL(string: "https://target.com")!
        ) {}

        let prompt = service.activeBlockedRedirect!
        #expect(prompt.sourceLabel == "this page")
    }

    @Test func testPromptHasCorrectTabID() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        let tabID = UUID()

        service.presentBlockedRedirect(
            tabID: tabID,
            sourceURL: URL(string: "https://a.com")!,
            targetURL: URL(string: "https://b.com")!
        ) {}

        #expect(service.activeBlockedRedirect?.tabID == tabID)
    }

    @Test func testNewPresentationReplacesExistingPrompt() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let tabID1 = UUID()
        let tabID2 = UUID()

        service.presentBlockedRedirect(
            tabID: tabID1,
            sourceURL: URL(string: "https://a.com")!,
            targetURL: URL(string: "https://b.com")!
        ) {}

        service.presentBlockedRedirect(
            tabID: tabID2,
            sourceURL: URL(string: "https://c.com")!,
            targetURL: URL(string: "https://d.com")!
        ) {}

        #expect(service.activeBlockedRedirect?.tabID == tabID2)
    }

    @Test func testEnabledStatePersistsViaUserDefaults() {
        let suiteName = "test.redirect.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let service1 = RedirectProtectionService(userDefaults: defaults)
        service1.isEnabled = false

        let service2 = RedirectProtectionService(userDefaults: defaults)
        #expect(service2.isEnabled == false)

        // Reset
        service1.isEnabled = true
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func testAllowedRulesPersistViaUserDefaults() {
        let suiteName = "test.redirect.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let service1 = RedirectProtectionService(userDefaults: defaults)
        service1.isEnabled = true

        service1.presentBlockedRedirect(
            tabID: UUID(),
            sourceURL: URL(string: "https://a.com")!,
            targetURL: URL(string: "https://b.com")!
        ) {}
        service1.allowBlockedRedirectAndProceed()

        let service2 = RedirectProtectionService(userDefaults: defaults)
        #expect(service2.allowedRedirectRules.count == 1)
        let tabID = UUID()
        #expect(service2.shouldBlockNavigation(
            from: URL(string: "https://a.com")!,
            to: URL(string: "https://b.com")!,
            tabID: tabID,
            isServerRedirect: true
        ) == false)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func testProfileScopedPersistence() {
        let suiteName = "test.redirect.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let profileA = UUID()
        let profileB = UUID()

        let serviceA = RedirectProtectionService(profileID: profileA, userDefaults: defaults)
        serviceA.isEnabled = false

        let serviceB = RedirectProtectionService(profileID: profileB, userDefaults: defaults)
        #expect(serviceB.isEnabled == true)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func testNoPersistenceWhenDisabled() {
        let suiteName = "test.redirect.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let service = RedirectProtectionService(userDefaults: defaults, isPersistenceEnabled: false)
        service.isEnabled = false

        let service2 = RedirectProtectionService(userDefaults: defaults)
        #expect(service2.isEnabled == true)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func testCaseInsensitiveHostMatching() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        service.isEnabled = true

        let source = URL(string: "https://Example.COM/page")!
        let target = URL(string: "https://example.com/other")!
        let tabID = UUID()

        #expect(service.shouldBlockNavigation(
            from: source, to: target, tabID: tabID, isServerRedirect: true
        ) == false)
    }

    @Test func testProceedWithNoActivePromptIsNoOp() {
        let service = RedirectProtectionService(isPersistenceEnabled: false)
        #expect(service.activeBlockedRedirect == nil)

        // Should not crash
        service.proceedWithBlockedRedirect()
        service.allowBlockedRedirectAndProceed()
        service.dismissPrompt()
    }

    @Test func testAllowedRedirectRuleIdentifiable() {
        let rule = RedirectProtectionService.AllowedRedirectRule(
            sourceIdentifier: "example.com",
            targetIdentifier: "partner.com"
        )

        #expect(rule.id != UUID())
        #expect(rule.sourceIdentifier == "example.com")
        #expect(rule.targetIdentifier == "partner.com")
    }

    @Test func testProceedResetsChainForTab() {
        let service = RedirectProtectionService(
            isPersistenceEnabled: false, chainDepthThreshold: 2, chainTimeWindow: 5.0
        )
        service.isEnabled = true
        let tabID = UUID()

        _ = service.shouldBlockNavigation(
            from: URL(string: "https://example.com")!,
            to: URL(string: "https://tracker.com")!,
            tabID: tabID,
            isServerRedirect: false
        )

        service.presentBlockedRedirect(
            tabID: tabID,
            sourceURL: URL(string: "https://example.com")!,
            targetURL: URL(string: "https://tracker.com")!
        ) {}
        service.proceedWithBlockedRedirect()

        let blocked = service.shouldBlockNavigation(
            from: URL(string: "https://tracker.com")!,
            to: URL(string: "https://another.com")!,
            tabID: tabID,
            isServerRedirect: false
        )

        #expect(blocked == false)
    }
}
