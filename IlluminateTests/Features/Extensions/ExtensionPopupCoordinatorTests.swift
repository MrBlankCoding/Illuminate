//
//  ExtensionPopupCoordinatorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/7/26.
//

import Foundation
import Testing
import WebKit
@testable import Illuminate

@MainActor
struct ExtensionPopupCoordinatorTests {

    @Test("initial state has no active popup")
    func initialState() {
        let coordinator = ExtensionPopupCoordinator()
        #expect(coordinator.activePopup == nil)
    }

    @Test("open sets activePopup")
    func openSetsActive() {
        let coordinator = ExtensionPopupCoordinator()
        let popup = ExtensionPopupCoordinator.PopupPayload(
            popupWebView: WKWebView(),
            extensionName: "Test",
            anchorX: 42
        )
        coordinator.open(popup)
        #expect(coordinator.activePopup != nil)
        #expect(coordinator.activePopup?.extensionName == "Test")
        #expect(coordinator.activePopup?.anchorX == 42)
    }

    @Test("close clears activePopup")
    func closeClears() {
        let coordinator = ExtensionPopupCoordinator()
        coordinator.open(.init(popupWebView: WKWebView(), extensionName: "A", anchorX: 0))
        coordinator.close()
        #expect(coordinator.activePopup == nil)
    }

    @Test("open after close replaces the active popup")
    func reopenReplaces() {
        let coordinator = ExtensionPopupCoordinator()
        let a = ExtensionPopupCoordinator.PopupPayload(popupWebView: WKWebView(), extensionName: "A", anchorX: 0)
        let b = ExtensionPopupCoordinator.PopupPayload(popupWebView: WKWebView(), extensionName: "B", anchorX: 100)

        coordinator.open(a)
        #expect(coordinator.activePopup?.extensionName == "A")
        coordinator.close()
        coordinator.open(b)
        #expect(coordinator.activePopup?.extensionName == "B")
        #expect(coordinator.activePopup?.anchorX == 100)
    }

    @Test("open without close overwrites previous popup")
    func openOverwrites() {
        let coordinator = ExtensionPopupCoordinator()
        let a = ExtensionPopupCoordinator.PopupPayload(popupWebView: WKWebView(), extensionName: "A", anchorX: 0)
        let b = ExtensionPopupCoordinator.PopupPayload(popupWebView: WKWebView(), extensionName: "B", anchorX: 100)

        coordinator.open(a)
        coordinator.open(b)
        #expect(coordinator.activePopup?.extensionName == "B")
        #expect(coordinator.activePopup?.popupWebView !== a.popupWebView)
    }

    @Test("close when already closed is a no-op")
    func closeWhenEmpty() {
        let coordinator = ExtensionPopupCoordinator()
        coordinator.close()
        #expect(coordinator.activePopup == nil)
    }
}
