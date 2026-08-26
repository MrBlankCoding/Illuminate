//
//  TabModelTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Testing
@testable import Illuminate

struct TabModelTests {
    @Test func networkErrorsExposeDistinctPresentation() {
        let errors: [NetworkErrorKind] = [
            .dns(host: "example.com"),
            .tls(message: "tls"),
            .noConnection(message: "offline"),
            .blocked(reason: "blocked"),
            .generic(message: "generic")
        ]
        #expect(errors.map(\.icon).count == 5)
        #expect(errors.map(\.title).count == 5)
        #expect(errors[0].detail.contains("example.com"))
        #expect(errors[1].detail == "tls")
        #expect(errors[2].detail == "offline")
        #expect(errors[3].detail == "blocked")
        #expect(errors[4].detail == "generic")
    }
}
