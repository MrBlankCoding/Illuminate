//
//  AppLog.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

// filter for only our logs: subsystem:com.MrBlankCoding.Illuminate


import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.illuminate.app"
    
    nonisolated static let infoLogger = Logger(subsystem: subsystem, category: "Info")
    nonisolated static let debugLogger = Logger(subsystem: subsystem, category: "Debug")
    nonisolated static let downloadLogger = Logger(subsystem: subsystem, category: "Download")
    nonisolated static let uiLogger = Logger(subsystem: subsystem, category: "UI")
    nonisolated static let securityLogger = Logger(subsystem: subsystem, category: "Security")
    nonisolated static let errorLogger = Logger(subsystem: subsystem, category: "Error")

    nonisolated static func info(_ message: String) {
        infoLogger.info("\(message, privacy: .public)")
    }
    
    nonisolated static func debug(_ message: String) {
        debugLogger.debug("\(message, privacy: .public)")
    }

    nonisolated static func download(_ message: String) {
        downloadLogger.info("\(message, privacy: .public)")
    }

    nonisolated static func ui(_ message: String) {
        uiLogger.info("\(message, privacy: .public)")
    }

    nonisolated static func security(_ message: String) {
        securityLogger.info("\(message, privacy: .public)")
    }

    nonisolated static func warning(_ message: String) {
        infoLogger.warning("\(message, privacy: .public)")
    }

    nonisolated static func error(_ message: String, error: Error? = nil) {
        if let error = error {
            errorLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            errorLogger.error("\(message, privacy: .public)")
        }
    }

    static func sanitizedURL(_ url: URL?) -> String {
        guard let url = url else { return "<nil>" }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.host ?? "unknown-host"
        }
        if components.queryItems != nil && !components.queryItems!.isEmpty {
            components.queryItems = [URLQueryItem(name: "redacted", value: nil)]
        }
        return components.url?.absoluteString ?? url.host ?? "unknown-host"
    }
}
