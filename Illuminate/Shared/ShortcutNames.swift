//
//  ShortcutNames.swift
//  Illuminate
//  Created by MrBlankCoding on 9/5/26. 
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let newTab                    = Self("newTab",                    initial: .init(.t,       modifiers: .command))
    static let closeTab                  = Self("closeTab",                  initial: .init(.w,       modifiers: .command))
    static let closeAllTabs              = Self("closeAllTabs",              initial: .init(.w,       modifiers: [.command, .shift]))
    static let reopenClosedTab           = Self("reopenClosedTab",           initial: .init(.t,       modifiers: [.command, .shift]))
    static let nextTab                   = Self("nextTab",                   initial: .init(.downArrow, modifiers: .command))
    static let previousTab               = Self("previousTab",               initial: .init(.upArrow,  modifiers: .command))
    static let switchToMostRecentTab     = Self("switchToMostRecentTab",     initial: .init(.tab,     modifiers: .control))
    static let newWindow                 = Self("newWindow",                 initial: .init(.n,       modifiers: .command))
    static let newPrivateWindow          = Self("newPrivateWindow",          initial: .init(.n,       modifiers: [.command, .shift]))
    static let openFile                  = Self("openFile",                  initial: .init(.o,       modifiers: .command))

    static let newTabGroup               = Self("newTabGroup",               initial: .init(.g,         modifiers: [.command, .option]))
    static let closeCurrentGroup         = Self("closeCurrentGroup",         initial: .init(.w,         modifiers: [.command, .option, .shift]))
    static let moveTabToLeftGroup        = Self("moveTabToLeftGroup",        initial: .init(.leftArrow,  modifiers: [.command, .option]))
    static let moveTabToRightGroup       = Self("moveTabToRightGroup",       initial: .init(.rightArrow, modifiers: [.command, .option]))

    static let focusURLBar               = Self("focusURLBar",               initial: .init(.l,           modifiers: .command))
    static let copyCurrentURL            = Self("copyCurrentURL",            initial: .init(.c,           modifiers: [.command, .shift]))
    static let reloadPage                = Self("reloadPage",                initial: .init(.r,           modifiers: .command))
    static let goBack                    = Self("goBack",                    initial: .init(.leftArrow,   modifiers: .command))
    static let goForward                 = Self("goForward",                 initial: .init(.rightArrow,  modifiers: .command))
    static let toggleFullScreen          = Self("toggleFullScreen",          initial: .init(.f,           modifiers: [.command, .shift]))

    static let showAllHistory            = Self("showAllHistory",            initial: .init(.y,    modifiers: .command))
    static let clearHistory              = Self("clearHistory",              initial: .init(.delete, modifiers: [.command, .shift]))

    static let findInPage                = Self("findInPage",                initial: .init(.f, modifiers: .command))
    static let printPage                 = Self("printPage",                 initial: .init(.p, modifiers: .command))
    static let savePageAsPDF             = Self("savePageAsPDF",             initial: .init(.s, modifiers: [.command, .shift]))
    static let zoomIn                    = Self("zoomIn",                    initial: .init(.equal, modifiers: .command))
    static let zoomOut                   = Self("zoomOut",                   initial: .init(.minus, modifiers: .command))
    static let resetZoom                 = Self("resetZoom",                 initial: .init(.zero,  modifiers: .command))
    static let developerTools            = Self("developerTools",            initial: .init(.i,    modifiers: [.command, .option]))

    static let bookmarkTab               = Self("bookmarkTab",               initial: .init(.b, modifiers: .command))
}

enum ShortcutGroup: String, CaseIterable, Identifiable {
    case tabsAndWindows = "Tabs & Windows"
    case tabGroups      = "Tab Groups"
    case navigation     = "Navigation"
    case history        = "History"
    case page           = "Page"
    case bookmarks      = "Bookmarks"

    var id: String { rawValue }

    var items: [(label: String, name: KeyboardShortcuts.Name)] {
        switch self {
        case .tabsAndWindows:
            return [
                ("New Tab",                  .newTab),
                ("Close Tab",                .closeTab),
                ("Close All Tabs",           .closeAllTabs),
                ("Reopen Closed Tab",        .reopenClosedTab),
                ("Next Tab",                 .nextTab),
                ("Previous Tab",             .previousTab),
                ("Switch to Most Recent Tab",.switchToMostRecentTab),
                ("New Window",               .newWindow),
                ("New Private Window",       .newPrivateWindow),
                ("Open File\u{2026}",        .openFile),
            ]
        case .tabGroups:
            return [
                ("New Tab Group",             .newTabGroup),
                ("Close Current Group",       .closeCurrentGroup),
                ("Move Tab to Left Group",    .moveTabToLeftGroup),
                ("Move Tab to Right Group",   .moveTabToRightGroup),
            ]
        case .navigation:
            return [
                ("Focus Address Bar",   .focusURLBar),
                ("Copy Current URL",    .copyCurrentURL),
                ("Reload Page",         .reloadPage),
                ("Go Back",             .goBack),
                ("Go Forward",          .goForward),
                ("Toggle Full Screen",  .toggleFullScreen),
            ]
        case .history:
            return [
                ("Show All History",    .showAllHistory),
                ("Clear History",       .clearHistory),
            ]
        case .page:
            return [
                ("Find in Page",        .findInPage),
                ("Save Page as PDF",    .savePageAsPDF),
                ("Print Page",          .printPage),
                ("Zoom In",             .zoomIn),
                ("Zoom Out",            .zoomOut),
                ("Actual Size",         .resetZoom),
                ("Developer Tools",     .developerTools),
            ]
        case .bookmarks:
            return [
                ("Bookmark Tab",        .bookmarkTab),
            ]
        }
    }
}
