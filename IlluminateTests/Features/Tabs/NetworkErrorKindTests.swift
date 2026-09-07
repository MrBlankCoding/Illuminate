//
//  NetworkErrorKindTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Testing
@testable import Illuminate

struct NetworkErrorKindTests {

    @Test("every error kind has a unique icon")
    func uniqueIcons() {
        let kinds: [NetworkErrorKind] = [
            .dns(host: "x"),
            .tls(message: "x"),
            .noConnection(message: "x"),
            .blocked(reason: "x"),
            .generic(message: "x"),
        ]
        let icons = Set(kinds.map(\.icon))
        #expect(icons.count == kinds.count)
    }

    @Test("every error kind has a non-empty title")
    func nonEmptyTitles() {
        let kinds: [NetworkErrorKind] = [
            .dns(host: "x"),
            .tls(message: "x"),
            .noConnection(message: "x"),
            .blocked(reason: "x"),
            .generic(message: "x"),
        ]
        for kind in kinds {
            #expect(!kind.title.isEmpty, "Title should be non-empty for \(kind)")
        }
    }

    @Test("DNS detail embeds the host name")
    func dnsDetailContainsHost() {
        let kind = NetworkErrorKind.dns(host: "example.com")
        #expect(kind.detail.contains("example.com"))
    }

    @Test("blocked detail is the reason verbatim")
    func blockedDetail() {
        let kind = NetworkErrorKind.blocked(reason: "Custom reason text")
        #expect(kind.detail == "Custom reason text")
    }

    @Test("tls detail is the message verbatim")
    func tlsDetail() {
        let kind = NetworkErrorKind.tls(message: "TLS error message")
        #expect(kind.detail == "TLS error message")
    }

    @Test("noConnection detail is the message verbatim")
    func noConnectionDetail() {
        let kind = NetworkErrorKind.noConnection(message: "Offline")
        #expect(kind.detail == "Offline")
    }

    @Test("generic detail is the message verbatim")
    func genericDetail() {
        let kind = NetworkErrorKind.generic(message: "Oops")
        #expect(kind.detail == "Oops")
    }

    @Test("equatable: same data is equal")
    func equatableSameData() {
        let a = NetworkErrorKind.dns(host: "x.com")
        let b = NetworkErrorKind.dns(host: "x.com")
        #expect(a == b)
    }

    @Test("equatable: different hosts are not equal")
    func equatableDifferentHosts() {
        let a = NetworkErrorKind.dns(host: "x.com")
        let b = NetworkErrorKind.dns(host: "y.com")
        #expect(a != b)
    }
}
