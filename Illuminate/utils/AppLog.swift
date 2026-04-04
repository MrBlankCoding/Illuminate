//
//  AppLog.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation

enum AppLog {
    static func info(_ message: String) {
        print("[Illuminate][INFO] \(message)")
    }

    static func download(_ message: String) {
        print("[Illuminate][DOWNLOAD] \(message)")
    }

    static func ui(_ message: String) {
        print("[Illuminate][UI] \(message)")
    }

    static func security(_ message: String) {
        print("[Illuminate][SECURITY] \(message)")
    }
}
