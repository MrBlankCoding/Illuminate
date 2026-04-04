//
//  BrowserWindowRoute.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/4/26.
//

import Foundation

enum BrowserWindowRoute: Hashable, Codable {
    case profile(UUID)
    case guest(UUID)

    nonisolated static func == (lhs: BrowserWindowRoute, rhs: BrowserWindowRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.profile(lhsID), .profile(rhsID)):
            return lhsID == rhsID
        case let (.guest(lhsID), .guest(rhsID)):
            return lhsID == rhsID
        default:
            return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case let .profile(identifier):
            hasher.combine(0)
            hasher.combine(identifier)
        case let .guest(identifier):
            hasher.combine(1)
            hasher.combine(identifier)
        }
    }
}

enum BrowserWindowOpenRequest: Equatable {
    case profileSelection
    case route(BrowserWindowRoute)

    nonisolated static func == (lhs: BrowserWindowOpenRequest, rhs: BrowserWindowOpenRequest) -> Bool {
        switch (lhs, rhs) {
        case (.profileSelection, .profileSelection):
            return true
        case let (.route(lhsRoute), .route(rhsRoute)):
            return lhsRoute == rhsRoute
        default:
            return false
        }
    }

    init?(url: URL) {
        guard url.scheme?.localizedCaseInsensitiveCompare("illuminate") == .orderedSame else {
            return nil
        }

        switch url.host?.lowercased() {
        case "new":
            self = .profileSelection
        case "profile":
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard let rawIdentifier = pathComponents.first,
                  let profileID = UUID(uuidString: rawIdentifier) else {
                return nil
            }
            self = .route(.profile(profileID))
        case "guest":
            self = .route(.guest(UUID()))
        default:
            return nil
        }
    }
}
