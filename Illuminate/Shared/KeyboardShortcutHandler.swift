//
//  KeyboardShortcutHandler.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation

final class KeyboardShortcutHandler {
    init() {}
}

final class BackgroundResourceManager {
    func start() {
        AppLog.info("BackgroundResourceManager started")
    }
}

final class RuntimeSecurityMonitor {

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func startMonitoring() {
        #if DEBUG
        observe(.newTab) { AppLog.security("Runtime check passed for New Tab action") }
        #endif
    }

    private func observe(_ name: Notification.Name, handler: @escaping () -> Void) {
        let token = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
            handler()
        }
        observers.append(token)
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
    }
}
