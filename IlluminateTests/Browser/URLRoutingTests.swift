//
//  URLRoutingTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/9/26.
//

import Testing
import Foundation
import WebKit
@testable import Illuminate

struct URLRoutingTests {
    @Test func testBrowserWindowDeepLinkRoutesToProfileSelection() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://new")!)

        #expect(request == .profileSelection)
    }

    @Test func testBrowserWindowDeepLinkRoutesToProfileWindow() {
        let profileID = UUID()
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile/\(profileID.uuidString)")!)

        #expect(request == .route(.profile(profileID)))
    }

    @Test func testBrowserWindowDeepLinkRejectsInvalidProfileIdentifier() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile/not-a-uuid")!)

        #expect(request == nil)
    }

    @Test func testBrowserWindowDeepLinkRejectsUnknownHosts() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://unsupported")!)

        #expect(request == nil)
    }

    @Test func testSearchQueryRouting() async throws {
        let tabManager = await MainActor.run { TabManager(isPersistenceEnabled: false) }
        let urlSynchronizer = await MainActor.run { URLSynchronizer() }
        let viewModel = await MainActor.run { ContentViewModel(tabManager: tabManager, urlSynchronizer: urlSynchronizer) }
        let tab = await MainActor.run {
            let t = tabManager.createTab()
            tabManager.switchTo(t.id)
            return t
        }
        
        await MainActor.run {
            viewModel.navigateToAddressBarURL("hello world")
        }
        
        let tabHost = await MainActor.run { tab.url?.host }
        let tabQuery = await MainActor.run { tab.url?.query }
        
        #expect(tabHost == "www.google.com")
        #expect(tabQuery?.contains("q=hello%20world") == true)
    }

    @Test func testAutoHTTPSRouting() async throws {
        let tabManager = await MainActor.run { TabManager(isPersistenceEnabled: false) }
        let urlSynchronizer = await MainActor.run { URLSynchronizer() }
        let viewModel = await MainActor.run { ContentViewModel(tabManager: tabManager, urlSynchronizer: urlSynchronizer) }
        let tab = await MainActor.run {
            let t = tabManager.createTab()
            tabManager.switchTo(t.id)
            return t
        }
        
        await MainActor.run {
            viewModel.navigateToAddressBarURL("apple.com")
        }
        
        let tabURL = await MainActor.run { tab.url?.absoluteString }
        
        #expect(tabURL == "https://apple.com")
    }

    @Test func testExistingSchemeIsPreserved() async throws {
        let (viewModel, tab) = await MainActor.run { makeViewModelAndTab() }

        await MainActor.run {
            viewModel.navigateToAddressBarURL("http://example.com")
        }

        let tabURL = await MainActor.run { tab.url?.absoluteString }
        #expect(tabURL == "http://example.com")
    }

    @Test func testPathAndQueryArePreservedWhenAddingHTTPS() async throws {
        let (viewModel, tab) = await MainActor.run { makeViewModelAndTab() }

        await MainActor.run {
            viewModel.navigateToAddressBarURL("example.com/path?q=1")
        }

        let tabURL = await MainActor.run { tab.url?.absoluteString }
        #expect(tabURL == "https://example.com/path?q=1")
    }

    @Test func testSingleWordWithoutDotRoutesToSearch() async throws {
        let (viewModel, tab) = await MainActor.run { makeViewModelAndTab() }

        await MainActor.run {
            viewModel.navigateToAddressBarURL("foo")
        }

        let tabURL = await MainActor.run { tab.url?.absoluteString }
        let tabHost = await MainActor.run { tab.url?.host }
        #expect(tabHost == "www.google.com")
        #expect(tabURL?.contains("q=foo") == true)
    }

    @Test func testWhitespaceRoutesToSearchWithEncodedQuery() async throws {
        let (viewModel, tab) = await MainActor.run { makeViewModelAndTab() }

        await MainActor.run {
            viewModel.navigateToAddressBarURL("a b")
        }

        let tabURL = await MainActor.run { tab.url?.absoluteString }
        let tabHost = await MainActor.run { tab.url?.host }
        #expect(tabHost == "www.google.com")
        #expect(tabURL?.contains("q=a%20b") == true)
    }

    @MainActor
    private func makeViewModelAndTab() -> (ContentViewModel, Tab) {
        let tabManager = TabManager(isPersistenceEnabled: false)
        let viewModel = ContentViewModel(tabManager: tabManager, urlSynchronizer: URLSynchronizer())
        let tab = tabManager.createTab()
        tabManager.switchTo(tab.id)
        return (viewModel, tab)
    }
}
