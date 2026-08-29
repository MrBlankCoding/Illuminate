//
//  AuthenticationService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/29/26.
//

import Foundation
import LocalAuthentication

enum AuthenticationError: Error, LocalizedError {
    case unavailable
    case failed
    case canceled
    case locked
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Biometric authentication or passcode is not available on this device."
        case .failed:
            return "Authentication failed."
        case .canceled:
            return "Authentication was canceled by the user."
        case .locked:
            return "Authentication is locked. Please try again later."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// simple yes or no
protocol AuthenticationServiceProtocol: Sendable {
    func authenticate(reason: String) async throws -> Bool
}

final class LocalAuthenticationService: AuthenticationServiceProtocol {
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                throw mapError(error)
            }
            throw AuthenticationError.unavailable
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success
        } catch let error as NSError {
            throw mapError(error)
        }
    }

    private func mapError(_ error: NSError) -> AuthenticationError {
        switch LAError(_nsError: error).code {
        case .userCancel, .appCancel, .systemCancel:
            return .canceled
        case .authenticationFailed:
            return .failed
        case .biometryNotAvailable, .biometryNotEnrolled:
            return .unavailable
        case .biometryLockout:
            return .locked
        default:
            return .unknown(error)
        }
    }
}
