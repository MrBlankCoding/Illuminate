//
//  UITestLaunchConfiguration.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/4/26.
//

import Foundation

enum UITestLaunchConfiguration {
    private static let uiTestingArgument = "--ui-testing"
    private static let resetStateArgument = "--ui-testing-reset-state"

    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    static func prepareAppStateIfNeeded(
        processInfo: ProcessInfo = .processInfo,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        let arguments = processInfo.arguments
        guard arguments.contains(resetStateArgument) else {
            return
        }

        try? fileManager.removeItem(at: fileManager.illuminateAppSupportDirectory())

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleIdentifier)
        }
    }
}
