//
//  ExtensionLogEntry.swift
//  Illuminate
//
//  Created by Kiro on 9/7/26.
//

import Foundation

/// Represents a single log entry for an extension
struct ExtensionLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    let extensionIdentifier: String
    
    enum LogLevel: String, Codable, Comparable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        
        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            let order: [LogLevel] = [.info, .warning, .error]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel, message: String, extensionIdentifier: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.extensionIdentifier = extensionIdentifier
    }
}

/// Manages logs for all extensions
@MainActor
@Observable
final class ExtensionLogManager {
    private(set) var logs: [ExtensionLogEntry] = []
    private let maxLogsPerExtension = 100
    private let maxTotalLogs = 500
    
    func log(level: ExtensionLogEntry.LogLevel, message: String, for extensionIdentifier: String) {
        let entry = ExtensionLogEntry(level: level, message: message, extensionIdentifier: extensionIdentifier)
        logs.append(entry)
        
        // Log to system logger
        switch level {
        case .info:
            AppLog.extensionInfo("[\(extensionIdentifier)] \(message)")
        case .warning:
            AppLog.extensionWarning("[\(extensionIdentifier)] \(message)")
        case .error:
            AppLog.extensionError("[\(extensionIdentifier)] \(message)")
        }
        
        // Cleanup old logs if needed
        trimLogsIfNeeded()
    }
    
    func logs(for extensionIdentifier: String) -> [ExtensionLogEntry] {
        logs.filter { $0.extensionIdentifier == extensionIdentifier }
    }
    
    func clearLogs(for extensionIdentifier: String) {
        logs.removeAll { $0.extensionIdentifier == extensionIdentifier }
    }
    
    func clearAllLogs() {
        logs.removeAll()
    }
    
    private func trimLogsIfNeeded() {
        // First, trim per-extension logs
        let grouped = Dictionary(grouping: logs, by: { $0.extensionIdentifier })
        var keptLogs: [ExtensionLogEntry] = []
        
        for (_, extensionLogs) in grouped {
            let sorted = extensionLogs.sorted { $0.timestamp > $1.timestamp }
            keptLogs.append(contentsOf: sorted.prefix(maxLogsPerExtension))
        }
        
        // Then, trim total logs if still too many
        if keptLogs.count > maxTotalLogs {
            keptLogs = keptLogs.sorted { $0.timestamp > $1.timestamp }.prefix(maxTotalLogs).map { $0 }
        }
        
        logs = keptLogs.sorted { $0.timestamp > $1.timestamp }
    }
}
