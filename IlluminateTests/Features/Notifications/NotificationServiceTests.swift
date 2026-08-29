//
//  NotificationServiceTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/29/26.
//

import Testing
import Foundation
import UserNotifications
@testable import Illuminate

@MainActor
struct NotificationServiceTests {

    @Test func testGetAuthorizationStatus() async throws {
        let service = NotificationService(statusProvider: { .authorized })
        let status = await service.getAuthorizationStatus()
        #expect(status == .authorized)
        
        let deniedService = NotificationService(statusProvider: { .denied })
        let deniedStatus = await deniedService.getAuthorizationStatus()
        #expect(deniedStatus == .denied)
    }

    @Test func testSendNotificationWhenNotAuthorizedThrows() async throws {
        let service = NotificationService(statusProvider: { .denied })
        
        await #expect(throws: NotificationError.notAuthorized) {
            try await service.sendNotification(title: "Test Title", body: "Test Body")
        }
    }
    
    @Test func testNotificationErrorDescription() {
        let error = NotificationError.notAuthorized
        #expect(error.localizedDescription == "Notification authorization was not granted.")
    }
}
