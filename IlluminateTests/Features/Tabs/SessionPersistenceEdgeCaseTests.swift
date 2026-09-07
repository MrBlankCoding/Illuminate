//
//  SessionPersistenceEdgeCaseTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct SessionPersistenceEdgeCaseTests {

    @Test("SessionState with empty tabIDs decodes to empty array")
    func emptyTabIDs() throws {
        let json = #"{"tabIDs":[],"tabs":[],"activeTabID":null}"#
        let state = try JSONDecoder().decode(SessionState.self, from: Data(json.utf8))
        #expect(state.tabIDs?.isEmpty == true)
        #expect(state.tabs?.isEmpty == true)
        #expect(state.activeTabID == nil)
    }

    @Test("SessionState missing tabs key has nil tabs")
    func missingTabsKey() throws {
        let json = #"{"tabIDs":["00000000-0000-0000-0000-000000000000"]}"#
        let state = try JSONDecoder().decode(SessionState.self, from: Data(json.utf8))
        #expect(state.tabs == nil)
        #expect(state.tabIDs?.count == 1)
    }

    @Test("SessionState missing tabIDs key has nil tabIDs")
    func missingTabIDsKey() throws {
        let payload = TabTransferPayload(id: UUID(), url: URL(string: "https://example.com"), title: "Example")
        let state = SessionState(tabs: [payload], activeTabID: nil)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SessionState.self, from: data)
        #expect(decoded.tabIDs == nil)
        #expect(decoded.tabs?.count == 1)
    }

    @Test("SessionState all-null decodes gracefully")
    func allNullFields() throws {
        let json = #"{"tabIDs":null,"tabs":null,"activeTabID":null}"#
        let state = try JSONDecoder().decode(SessionState.self, from: Data(json.utf8))
        #expect(state.tabIDs == nil)
        #expect(state.tabs == nil)
        #expect(state.activeTabID == nil)
    }

    @Test("SessionState with invalid JSON throws decoding error")
    func malformedJSONThrows() throws {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(SessionState.self, from: Data("not json".utf8))
        }
    }

    @Test("TabTransferPayload preserves a nil title")
    func tabPayloadNilTitle() throws {
        let payload = TabTransferPayload(id: UUID(), url: URL(string: "https://example.com"), title: nil)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(TabTransferPayload.self, from: data)
        #expect(decoded.url?.absoluteString == "https://example.com")
        #expect(decoded.title == nil)
    }

    @Test("TabTransferPayload with nil URL round-trips")
    func tabPayloadNilURL() throws {
        let payload = TabTransferPayload(id: UUID(), url: nil, title: "Untitled")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(TabTransferPayload.self, from: data)
        #expect(decoded.url == nil)
        #expect(decoded.title == "Untitled")
    }

    @Test("makeSessionURL is deterministic per profileID")
    func sessionURLDeterministic() {
        let profileID = UUID()
        let first = TabManager.makeSessionURL(profileID: profileID)
        let second = TabManager.makeSessionURL(profileID: profileID)
        #expect(first == second)
    }

    @Test("makeSessionURL uses app support dir for nil profileID")
    func sessionURLNilProfile() {
        let url = TabManager.makeSessionURL(profileID: nil)
        #expect(url.lastPathComponent == "session.json")
        #expect(url.path.contains("Illuminate"))
    }

    @Test("makeSessionURL varies per profileID")
    func sessionURLDiffersByProfile() {
        let first = TabManager.makeSessionURL(profileID: UUID())
        let second = TabManager.makeSessionURL(profileID: UUID())
        #expect(first != second)
    }
}
