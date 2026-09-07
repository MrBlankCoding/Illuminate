//
//  ExtensionPopupSwitchTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
import WebKit
@testable import Illuminate

@MainActor
struct ExtensionPopupSwitchTests {

    private func makePayload(_ name: String) -> ExtensionPopupCoordinator.PopupPayload {
        ExtensionPopupCoordinator.PopupPayload(
            popupWebView: WKWebView(),
            extensionName: name,
            anchorX: 100
        )
    }

    @Test("close followed by open replaces the active popup")
    func closeThenOpenReplaces() {
        let coordinator = ExtensionPopupCoordinator()
        let a = makePayload("A")
        let b = makePayload("B")

        coordinator.open(a)
        #expect(coordinator.activePopup?.extensionName == "A")

        // simulate clicking B while A is open
        coordinator.close()
        #expect(coordinator.activePopup == nil)

        coordinator.open(b)
        #expect(coordinator.activePopup?.extensionName == "B")
        #expect(coordinator.activePopup?.popupWebView !== a.popupWebView)
        #expect(coordinator.activePopup?.popupWebView === b.popupWebView)
    }

    @Test("open while a popup is active replaces (not appends)")
    func openOverwritesActive() {
        let coordinator = ExtensionPopupCoordinator()
        let a = makePayload("A")
        let b = makePayload("B")

        coordinator.open(a)
        coordinator.open(b) // direct switch, no explicit close

        #expect(coordinator.activePopup?.extensionName == "B")
        #expect(coordinator.activePopup?.popupWebView === b.popupWebView)
    }

    @Test("switching to same extension name is idempotent")
    func switchToSameName() {
        let coordinator = ExtensionPopupCoordinator()
        let a = makePayload("A")

        coordinator.open(a)
        #expect(coordinator.activePopup?.extensionName == "A")
        // Reopening the same extension: activePopup should remain "A".
        coordinator.open(a)
        #expect(coordinator.activePopup?.extensionName == "A")
    }

    @Test("sequential switches keep the latest payload")
    func sequentialSwitches() {
        let coordinator = ExtensionPopupCoordinator()
        let a = makePayload("A")
        let b = makePayload("B")
        let c = makePayload("C")

        coordinator.open(a)
        coordinator.close()
        coordinator.open(b)
        coordinator.close()
        coordinator.open(c)

        #expect(coordinator.activePopup?.extensionName == "C")
        #expect(coordinator.activePopup?.popupWebView === c.popupWebView)
    }

    @Test("close when no popup active is safe")
    func closeWhenEmpty() {
        let coordinator = ExtensionPopupCoordinator()
        coordinator.close()
        #expect(coordinator.activePopup == nil)
    }
}
