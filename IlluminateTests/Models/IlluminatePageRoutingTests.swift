//
//  IlluminatePageRoutingTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct IlluminatePageRoutingTests {
        @Test func illuminateInfoPageRoutesCorrectly() {
        let url = URL(string: "illuminate://info")!
        let page = IlluminatePage(url: url)
        #expect(page == .info)
        #expect(page?.url == url)
    }
}

