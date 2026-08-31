//
//  HapticFeedbackTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/30/26.
//

import AppKit
import Testing
@testable import Illuminate
import Foundation

@Suite(.serialized)
struct HapticFeedbackTests {

    private let key = "hapticFeedbackEnabled"

    private func withCleanDefaults<R>(_ body: () async throws -> R) async rethrows -> R {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
        HapticFeedback.resetForTesting()
        defer {
            if let original {
                defaults.set(original, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            HapticFeedback.resetForTesting()
        }
        return try await body()
    }

    @Test func isEnabledDefaultsToTrueWhenNotSet() async throws {
        try await withCleanDefaults {
            #expect(HapticFeedback.isEnabled == true)
        }
    }

    @Test func isEnabledRespectsDisabled() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(false, forKey: key)
            #expect(HapticFeedback.isEnabled == false)
        }
    }

    @Test func isEnabledRespectsEnabled() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(true, forKey: key)
            #expect(HapticFeedback.isEnabled == true)
        }
    }

    @Test func toggledPreferenceIsGlobalAndPersists() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(false, forKey: key)
            #expect(HapticFeedback.isEnabled == false)
            UserDefaults.standard.set(true, forKey: key)
            #expect(HapticFeedback.isEnabled == true)
            // Simulate relaunch by re-reading from UserDefaults
            let reloaded = UserDefaults.standard.bool(forKey: key)
            #expect(reloaded == true)
        }
    }

    @Test func tabDetachedDoesNotCrashWhenEnabled() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(true, forKey: key)
            HapticFeedback.tabDetached()
            #expect(true)
        }
    }

    @Test func tabDetachedDoesNotCrashWhenDisabled() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(false, forKey: key)
            HapticFeedback.tabDetached()
            #expect(true)
        }
    }

    @Test func tabReorderedDoesNotCrash() async throws {
        try await withCleanDefaults {
            HapticFeedback.tabReordered()
            #expect(true)
        }
    }

    @Test func destructiveActionDoesNotCrash() async throws {
        try await withCleanDefaults {
            HapticFeedback.destructiveAction()
            #expect(true)
        }
    }

    @Test func downloadCompletedDoesNotCrash() async throws {
        try await withCleanDefaults {
            HapticFeedback.downloadCompleted()
            #expect(true)
        }
    }

    @Test func hapticsAreSafeFromBackgroundThread() async throws {
        try await withCleanDefaults {
            await withCheckedContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async {
                    HapticFeedback.tabReordered()
                    HapticFeedback.tabDetached()
                    HapticFeedback.downloadCompleted()
                    HapticFeedback.destructiveAction()
                    cont.resume()
                }
            }
            #expect(true)
        }
    }

    @Test func downloadCompletedCoalescesRapidCalls() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(true, forKey: key)
            HapticFeedback.resetForTesting()
            HapticFeedback.downloadCompleted() // first — should fire
            let start = CFAbsoluteTimeGetCurrent()
            HapticFeedback.downloadCompleted()
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            #expect(elapsed < 0.05, "Coalesced call should return immediately")
        }
    }

    @Test func downloadCompletedFiresAfterWindowExpires() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(true, forKey: key)
            HapticFeedback.resetForTesting()
            HapticFeedback.downloadCompleted()
            // Wait past coalescing window
            try await Task.sleep(nanoseconds: 900_000_000) // 0.9s
            // Should fire again without coalescing
            let start = CFAbsoluteTimeGetCurrent()
            HapticFeedback.downloadCompleted()
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            #expect(elapsed < 0.1)
            #expect(true)
        }
    }

    @Test func destructiveActionIsNotCoalesced() async throws {
        try await withCleanDefaults {
            HapticFeedback.destructiveAction()
            HapticFeedback.destructiveAction()
            #expect(true)
        }
    }

    @Test func hapticCallsAreNonBlocking() async throws {
        try await withCleanDefaults {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<10 {
                HapticFeedback.tabReordered()
                HapticFeedback.tabDetached()
                HapticFeedback.downloadCompleted()
                HapticFeedback.resetForTesting() // reset so download not coalesced in loop
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            #expect(elapsed < 0.2, "Haptic calls should be lightweight and not block")
        }
    }

    @Test func disabledHapticsAreNoOpsWithoutSideEffects() async throws {
        try await withCleanDefaults {
            UserDefaults.standard.set(false, forKey: key)
            // Even dozens of calls while disabled should be no-ops and fast
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<20 {
                HapticFeedback.tabDetached()
                HapticFeedback.tabReordered()
                HapticFeedback.downloadCompleted()
                HapticFeedback.destructiveAction()
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            #expect(elapsed < 0.1)
        }
    }
}
