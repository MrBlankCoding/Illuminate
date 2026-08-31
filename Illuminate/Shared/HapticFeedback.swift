//
//  HapticFeedback.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

// haptic controller for the browser
// I didnt even know macs could do this
// soo cool apple :)

import AppKit

enum HapticFeedback {
    private static let enabledKey = "hapticFeedbackEnabled"

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func tabDetached() {
        log("tabDetached", pattern: .alignment)
        perform(.alignment, performanceTime: .now)
    }

    static func tabReordered() {
        log("tabReordered", pattern: .alignment)
        perform(.alignment, performanceTime: .now)
    }

    // Careful with mutiple downloads
    static func downloadCompleted() {
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastDownloadHaptic < 0.8 {
            AppLog.debug("Haptic coalesced: downloadCompleted (generic) — within 0.8s window")
            return
        }
        lastDownloadHaptic = now
        log("downloadCompleted", pattern: .generic)
        perform(.generic, performanceTime: .now)
    }

    static func destructiveAction() {
        log("destructiveAction", pattern: .levelChange)
        perform(.levelChange, performanceTime: .now)
    }

    static func newTabButtonPressed() {
        log("newTabButtonPressed", pattern: .alignment)
        perform(.alignment, performanceTime: .now)
    }


    private static var lastDownloadHaptic: CFAbsoluteTime = 0

    static func resetForTesting() {
        lastDownloadHaptic = 0
    }

    private static func log(_ event: String, pattern: NSHapticFeedbackManager.FeedbackPattern) {
        let patternName: String
        switch pattern {
        case .generic: patternName = "generic"
        case .alignment: patternName = "alignment"
        case .levelChange: patternName = "levelChange"
        @unknown default: patternName = "unknown(\(pattern))"
        }
        AppLog.debug("Haptic triggered: \(event) (pattern: \(patternName)) — enabled: \(isEnabled)")
        print("[HAPTIC] \(event) → \(patternName) (enabled=\(isEnabled))")
    }

    private static func perform(
        _ pattern: NSHapticFeedbackManager.FeedbackPattern,
        performanceTime: NSHapticFeedbackManager.PerformanceTime
    ) {
        guard isEnabled else {
            AppLog.debug("Haptic skipped (disabled): \(pattern)")
            return
        }
        // main thread 
        if Thread.isMainThread {
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: performanceTime)
        } else {
            DispatchQueue.main.async {
                NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: performanceTime)
            }
        }
    }
}
