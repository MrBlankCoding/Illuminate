//
//  WebURLOpeningTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/27/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct WebURLOpeningTests {

    @Test func routeToRegisteredTabManagerOpensNewTab() {
        WebURLOpening.shared.resetForTesting()
        let tabManager = TabManager(isPersistenceEnabled: false)
        WebURLOpening.shared.register(tabManager)

        let initialCount = tabManager.tabs.count
        WebURLOpening.shared.handle(URL(string: "https://example.com")!)

        #expect(tabManager.tabs.count == initialCount + 1)
        #expect(tabManager.tabs.last?.url == URL(string: "https://example.com"))
        #expect(WebURLOpening.shared.queuedURLs.isEmpty)
        #expect(!WebURLOpening.shared.needsBrowserWindow)
    }

    @Test func routeWithNoWindowQueuesAndRequestsBrowserWindow() {
        WebURLOpening.shared.resetForTesting()

        WebURLOpening.shared.handle(URL(string: "https://example.com")!)

        #expect(WebURLOpening.shared.queuedURLs == [URL(string: "https://example.com")!])
        #expect(WebURLOpening.shared.needsBrowserWindow)
    }

    @Test func drainOpensQueuedTabs() {
        WebURLOpening.shared.resetForTesting()
        let tabManager = TabManager(isPersistenceEnabled: false)

        WebURLOpening.shared.handle(URL(string: "https://example.com/1")!)
        WebURLOpening.shared.handle(URL(string: "https://example.com/2")!)

        WebURLOpening.shared.drainIfNeeded(into: tabManager)

        // The auto-created blank "New Tab" placeholder is replaced by the queued
        // URLs so the user lands on the opened links instead of a profile page.
        #expect(tabManager.tabs.count == 2)
        #expect(tabManager.tabs.map(\.url) == [
            URL(string: "https://example.com/1"),
            URL(string: "https://example.com/2"),
        ])
        #expect(WebURLOpening.shared.queuedURLs.isEmpty)
        #expect(!WebURLOpening.shared.needsBrowserWindow)
    }

    @Test func nonNavigableSchemesAreIgnored() {
        WebURLOpening.shared.resetForTesting()
        let tabManager = TabManager(isPersistenceEnabled: false)
        WebURLOpening.shared.register(tabManager)
        let initialCount = tabManager.tabs.count

        WebURLOpening.shared.handle(URL(string: "illuminate://new")!)

        #expect(tabManager.tabs.count == initialCount)
        #expect(WebURLOpening.shared.queuedURLs.isEmpty)
    }

    @Test func registeringDrainsQueuedURLs() {
        WebURLOpening.shared.resetForTesting()
        WebURLOpening.shared.handle(URL(string: "https://example.com")!)

        let tabManager = TabManager(isPersistenceEnabled: false)
        WebURLOpening.shared.register(tabManager)

        #expect(tabManager.tabs.last?.url == URL(string: "https://example.com"))
        #expect(WebURLOpening.shared.queuedURLs.isEmpty)
    }
}
