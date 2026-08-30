//
//  NotificationService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/29/26.
//

import Foundation
import UserNotifications
import Observation

protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func getAuthorizationStatus() async -> UNAuthorizationStatus
    func sendNotification(title: String, body: String, identifier: String?) async throws
}

@MainActor
@Observable
final class NotificationService: NSObject, NotificationServiceProtocol {
    
    static let shared = NotificationService()
    
    @ObservationIgnored private let center: UNUserNotificationCenter
    @ObservationIgnored private let statusProvider: @MainActor () async -> UNAuthorizationStatus
    
    init(
        center: UNUserNotificationCenter = .current(),
        statusProvider: @escaping @MainActor () async -> UNAuthorizationStatus = {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus
        }
    ) {
        self.center = center
        self.statusProvider = statusProvider
        super.init()
        self.center.delegate = self
    }
    
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        return try await center.requestAuthorization(options: options)
    }
    
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        return await statusProvider()
    }
    
    // title
    // body 
    // identifier
    func sendNotification(title: String, body: String, identifier: String? = nil) async throws {
        let status = await getAuthorizationStatus()
        
        guard status == .authorized else {
            throw NotificationError.notAuthorized
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let requestIdentifier = identifier ?? UUID().uuidString
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        try await center.add(request)
    }
}


extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // show even when app is focused?
        return [.banner, .sound]
    }
}


enum NotificationError: LocalizedError {
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notification authorization was not granted."
        }
    }
}
