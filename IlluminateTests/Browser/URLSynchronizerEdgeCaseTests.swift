//
//  URLSynchronizerEdgeCaseTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
import Observation
@testable import Illuminate

@MainActor
struct URLSynchronizerEdgeCaseTests {

    @Test("setting the same URL twice does not trigger a second observation")
    func sameValueNoOp() {
        let sync = URLSynchronizer()
        let url = URL(string: "https://example.com")!

        var observedChanges = 0
        let token = withObservationTracking {
            _ = sync.currentURL
        } onChange: {
            observedChanges += 1
        }
        _ = token

        sync.updateCurrentURL(url)
        #expect(observedChanges == 1)
        sync.updateCurrentURL(url)
        #expect(observedChanges == 1, "Second update with same value should not fire onChange")
    }

    @Test("setting nil clears the URL")
    func settingNilClears() {
        let sync = URLSynchronizer()
        sync.updateCurrentURL(URL(string: "https://example.com")!)
        sync.updateCurrentURL(nil)
        #expect(sync.currentURL == nil)
    }

    @Test("changing between two URLs updates currentURL")
    func changingURLs() {
        let sync = URLSynchronizer()
        let a = URL(string: "https://a.example")!
        let b = URL(string: "https://b.example")!
        sync.updateCurrentURL(a)
        sync.updateCurrentURL(b)
        #expect(sync.currentURL == b)
    }

    @Test("initial state is nil")
    func initialStateNil() {
        let sync = URLSynchronizer()
        #expect(sync.currentURL == nil)
    }
}
