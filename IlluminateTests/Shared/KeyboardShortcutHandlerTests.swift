//
//  KeyboardShortcutHandlerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import AppKit
import Testing
@testable import Illuminate

struct KeyboardShortcutHandlerTests {
    private let handler = KeyboardShortcutHandler()

    @Test func commandTMapsToNewTab() { #expect(handler.lookupShortcutBy(character: "t", modifiers: .command) == .newTab) }
    @Test func commandWMapsToCloseActiveTab() { #expect(handler.lookupShortcutBy(character: "w", modifiers: .command) == .closeActiveTab) }
    @Test func commandLMapsToFocusURLBar() { #expect(handler.lookupShortcutBy(character: "l", modifiers: .command) == .focusURLBar) }
    @Test func commandRMapsToReload() { #expect(handler.lookupShortcutBy(character: "r", modifiers: .command) == .reloadActiveTab) }
    @Test func commandBMapsToBookmark() { #expect(handler.lookupShortcutBy(character: "b", modifiers: .command) == .bookmarkTab) }
    @Test func commandFMapsToFind() { #expect(handler.lookupShortcutBy(character: "f", modifiers: .command) == .findInPage) }
    @Test func commandPlusMapsToZoomIn() { #expect(handler.lookupShortcutBy(character: "+", modifiers: .command) == .zoomIn) }
    @Test func commandEqualsMapsToZoomIn() { #expect(handler.lookupShortcutBy(character: "=", modifiers: .command) == .zoomIn) }
    @Test func commandMinusMapsToZoomOut() { #expect(handler.lookupShortcutBy(character: "-", modifiers: .command) == .zoomOut) }
    @Test func commandZeroMapsToResetZoom() { #expect(handler.lookupShortcutBy(character: "0", modifiers: .command) == .resetZoom) }
    @Test func commandShiftIMapsToDeveloperTools() { #expect(handler.lookupShortcutBy(character: "i", modifiers: [.command, .shift]) == .openDevTools) }
    @Test func commandShiftTMapsToReopenTab() { #expect(handler.lookupShortcutBy(character: "t", modifiers: [.command, .shift]) == .reopenTab) }
    @Test func commandShiftWMapsToCloseAllTabs() { #expect(handler.lookupShortcutBy(character: "w", modifiers: [.command, .shift]) == .closeAllTabs) }
    @Test func commandShiftFMapsToFullscreen() { #expect(handler.lookupShortcutBy(character: "f", modifiers: [.command, .shift]) == .toggleFullScreen) }
    @Test func uppercaseCharactersMatchCaseInsensitively() { #expect(handler.lookupShortcutBy(character: "T", modifiers: .command) == .newTab) }
    @Test func unmappedCharacterReturnsNil() { #expect(handler.lookupShortcutBy(character: "q", modifiers: .command) == nil) }
    @Test func wrongCharacterModifiersReturnNil() { #expect(handler.lookupShortcutBy(character: "t", modifiers: .shift) == nil) }
    @Test func commandLeftArrowMapsToBack() { #expect(handler.lookupShortcutBy(keyCode: 123, modifiers: .command) == .goBack) }
    @Test func commandRightArrowMapsToForward() { #expect(handler.lookupShortcutBy(keyCode: 124, modifiers: .command) == .goForward) }
    @Test func commandDownArrowMapsToNextTab() { #expect(handler.lookupShortcutBy(keyCode: 125, modifiers: .command) == .nextTab) }
    @Test func commandUpArrowMapsToPreviousTab() { #expect(handler.lookupShortcutBy(keyCode: 126, modifiers: .command) == .previousTab) }
    @Test func unmappedKeyCodeReturnsNil() { #expect(handler.lookupShortcutBy(keyCode: 42, modifiers: .command) == nil) }
    @Test func wrongArrowModifiersReturnNil() { #expect(handler.lookupShortcutBy(keyCode: 123, modifiers: [.command, .shift]) == nil) }
}
