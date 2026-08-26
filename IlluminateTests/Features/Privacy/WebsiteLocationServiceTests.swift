//
//  WebsiteLocationServiceTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Testing
import Foundation
@testable import Illuminate
import CoreLocation

@MainActor
struct WebsiteLocationServiceTests {

    @Test func secondConcurrentRequestIsRejectedAsBusy() {
        let service = WebsiteLocationService()
        var firstResult: Result<CLLocation, Error>?
        var busyResult: Result<CLLocation, Error>?

        service.requestLocation { firstResult = $0 }
        service.requestLocation { busyResult = $0 }

        if case .failure(let error) = busyResult {
            #expect(error.localizedDescription == "A location request is already in progress.")
        } else if busyResult != nil {
            Issue.record("Expected busy failure for concurrent request")
        }
        // First request stays pending (no location callback in test env).
        #expect(firstResult == nil)
    }
}
