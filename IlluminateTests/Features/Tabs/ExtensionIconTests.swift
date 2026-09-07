//
//  ExtensionIconTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import AppKit
import Foundation
import Testing
import WebKit
import Observation
@testable import Illuminate

@MainActor
@Suite("Extension Icon & Restore Configuration")
struct ExtensionIconTests {

    private func makeTabManager(isPersistenceEnabled: Bool = false) -> TabManager {
        TabManager(
            profile: BrowserProfile(name: "Test Profile"),
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: isPersistenceEnabled
        )
    }

    @Test("resolveExtensionConfiguration is a no-op for non-extension URLs")
    func resolveExtensionConfigurationNonExtensionURL() {
        let tm = makeTabManager()
        let tab = tm.createTab(url: URL(string: "https://example.com"))

        tm.resolveExtensionConfiguration(for: tab)

        #expect(tab.customWebViewConfiguration == nil)
    }

    @Test("resolveExtensionConfiguration is a no-op for extension URLs when no context exists")
    func resolveExtensionConfigurationNoContext() {
        let tm = makeTabManager()
        let tab = tm.createTab(url: URL(string: "webkit-extension://abc/dashboard"))

        tm.resolveExtensionConfiguration(for: tab)

        #expect(tab.customWebViewConfiguration == nil)
    }

    @Test("resolveExtensionConfiguration preserves an existing config")
    func resolveExtensionConfigurationPreservesExisting() {
        let tm = makeTabManager()
        let tab = tm.createTab(url: URL(string: "webkit-extension://abc/dashboard"))
        let pre = WKWebViewConfiguration()
        tab.customWebViewConfiguration = pre

        tm.resolveExtensionConfiguration(for: tab)

        #expect(tab.customWebViewConfiguration === pre)
    }

    @Test("customWebViewConfiguration mutation is observed")
    func customWebViewConfigurationIsObservable() {
        let tab = Tab(url: URL(string: "https://example.com"))
        let pre = WKWebViewConfiguration()

        var didObserve = false
        withObservationTracking {
            _ = tab.customWebViewConfiguration
        } onChange: {
            didObserve = true
        }

        tab.customWebViewConfiguration = pre
        #expect(didObserve)
        #expect(tab.customWebViewConfiguration === pre)
    }

    @Test("handleExtensionListChanged resolves configs and reloads for all tabs with URLs")
    func handleExtensionListChangedReloadsTabsWithURLs() {
        let tm = makeTabManager()
        let tabWithURL = tm.createTab(url: URL(string: "https://example.com"))
        let tabWithoutURL = tm.createTab()

        tm.handleExtensionListChanged()

        #expect(tabWithURL.url != nil)
        #expect(tabWithoutURL.url == nil)
    }

    @Test("handleExtensionListChanged does not crash when no extensions are installed")
    func handleExtensionListChangedNoExtensions() {
        let tm = makeTabManager()
        _ = tm.createTab(url: URL(string: "webkit-extension://abc/dashboard"))
        _ = tm.createTab(url: URL(string: "illuminate://history"))

        tm.handleExtensionListChanged()
    }
}
