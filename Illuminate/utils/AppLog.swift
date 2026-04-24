//
//  AppLog.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation

enum AppLog {
    nonisolated static func info(_ message: String) {
        print("[Illuminate][INFO] \(message)")
    }

    nonisolated static func download(_ message: String) {
        print("[Illuminate][DOWNLOAD] \(message)")
    }

    nonisolated static func ui(_ message: String) {
        print("[Illuminate][UI] \(message)")
    }

    nonisolated static func security(_ message: String) {
        print("[Illuminate][SECURITY] \(message)")
    }
}
