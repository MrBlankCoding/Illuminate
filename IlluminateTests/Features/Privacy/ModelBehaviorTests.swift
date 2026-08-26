//
//  ModelBehaviorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 4/4/26.
//

import Foundation
import Testing
@testable import Illuminate

struct ModelBehaviorTests {

    @Test func cookieViewModelFiltersByDomainAndSearchText() throws {
        let viewModel = CookieViewModel(domain: "example.com")
        viewModel.cookies = [
            try makeCookie(domain: ".example.com", name: "session"),
            try makeCookie(domain: "accounts.example.com", name: "auth"),
            try makeCookie(domain: "other.com", name: "tracking")
        ]

        #expect(viewModel.filteredCookies.count == 2)

        viewModel.searchText = "auth"

        #expect(viewModel.filteredCookies.count == 1)
        #expect(viewModel.filteredCookies.first?.name == "auth")
    }

    @Test func cookieViewModelGroupsAndSortsDomains() throws {
        let viewModel = CookieViewModel()
        viewModel.cookies = [
            try makeCookie(domain: "zeta.example", name: "z"),
            try makeCookie(domain: "alpha.example", name: "a1"),
            try makeCookie(domain: "alpha.example", name: "a2")
        ]

        #expect(viewModel.groupedCookies["alpha.example"]?.count == 2)
        #expect(viewModel.groupedCookies["zeta.example"]?.count == 1)
        #expect(viewModel.sortedDomains == ["alpha.example", "zeta.example"])
    }

    private func makeCookie(domain: String, name: String) throws -> HTTPCookie {
        let properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .path: "/",
            .name: name,
            .value: "value-\(name)",
            .secure: "TRUE"
        ]

        return try #require(HTTPCookie(properties: properties))
    }
}
