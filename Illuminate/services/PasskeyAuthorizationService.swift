//
//  PasskeyAuthorizationService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/13/25.
//

import AuthenticationServices
import Foundation

@MainActor
final class PasskeyAuthorizationService {
    static let shared = PasskeyAuthorizationService()

    private var hasRequestedAuthorization = false

    private init() {}

    func requestAccessIfNeeded() {
        guard !hasRequestedAuthorization else { return }

        hasRequestedAuthorization = true

        let credentialManager = ASAuthorizationWebBrowserPublicKeyCredentialManager()
        switch credentialManager.authorizationStateForPlatformCredentials {
        case .authorized:
            AppLog.info("Passkey browser access already authorized")
        case .denied:
            AppLog.security("Passkey browser access denied in system settings")
        case .notDetermined:
            credentialManager.requestAuthorizationForPublicKeyCredentials { state in
                Task { @MainActor in
                    switch state {
                    case .authorized:
                        AppLog.info("Passkey browser access granted")
                    case .denied:
                        AppLog.security("Passkey browser access denied by user")
                    case .notDetermined:
                        AppLog.security("Passkey browser access request ended without a decision")
                    @unknown default:
                        AppLog.security("Passkey browser access returned an unknown state")
                    }
                }
            }
        @unknown default:
            AppLog.security("Passkey browser access is in an unknown state")
        }
    }
}
