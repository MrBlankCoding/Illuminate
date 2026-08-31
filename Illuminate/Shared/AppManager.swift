//
//  AppManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import Darwin

extension Notification.Name {
    static let newTab = Notification.Name("app.newTab")
    static let focusURLBar = Notification.Name("app.focusURLBar")
    static let copyCurrentURL = Notification.Name("app.copyCurrentURL")
    static let switchToMostRecentTab = Notification.Name("app.switchToMostRecentTab")

    static let openBookmarks = Notification.Name("app.openBookmarks")
    static let reloadActiveTab = Notification.Name("app.reloadActiveTab")
    static let goBack = Notification.Name("app.goBack")
    static let goForward = Notification.Name("app.goForward")
    static let bookmarkTab = Notification.Name("app.bookmarkTab")
    static let reopenTab = Notification.Name("app.reopenTab")
    static let nextTab = Notification.Name("app.nextTab")
    static let previousTab = Notification.Name("app.previousTab")
    static let toggleSidebar = Notification.Name("app.toggleSidebar")
    static let openDevTools = Notification.Name("app.openDevTools")
    static let findInPage = Notification.Name("app.findInPage")
    static let zoomIn = Notification.Name("app.zoomIn")
    static let zoomOut = Notification.Name("app.zoomOut")
    static let resetZoom = Notification.Name("app.resetZoom")
    static let printPage = Notification.Name("app.printPage")
    static let savePageAsPDF = Notification.Name("app.savePageAsPDF")
    static let zoomChanged = Notification.Name("app.zoomChanged")
    static let toggleFullScreen = Notification.Name("app.toggleFullScreen")
    static let closeActiveTab = Notification.Name("app.closeActiveTab")
    static let closeAllTabs = Notification.Name("app.closeAllTabs")
    static let downloadsDidChange = Notification.Name("app.downloadsDidChange")
    static let openNewWindowFromExtension = Notification.Name("app.openNewWindow")

    static let showHistory       = Notification.Name("app.showHistory")
    static let clearHistory      = Notification.Name("app.clearHistory")
    static let newPrivateWindow  = Notification.Name("app.newPrivateWindow")
    static let openURL           = Notification.Name("app.openURL")
    static let pendingFilesChanged = Notification.Name("app.pendingFilesChanged")
    static let newTabGroup       = Notification.Name("app.newTabGroup")
    static let closeCurrentGroup = Notification.Name("app.closeCurrentGroup")
    static let moveTabToLeftGroup  = Notification.Name("app.moveTabToLeftGroup")
    static let moveTabToRightGroup = Notification.Name("app.moveTabToRightGroup")
    static let newEasel            = Notification.Name("app.newEasel")
}


extension FileManager {
    nonisolated func illuminateAppSupportDirectory() -> URL {
        let baseDirectory = urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        let appDirectory = baseDirectory.appendingPathComponent("Illuminate", isDirectory: true)
        try? createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
    }

    nonisolated func illuminateDownloadsDirectory() -> URL {
        let downloadsDirectory = realUserDownloadsDirectory()
            ?? urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? temporaryDirectory.appendingPathComponent("Downloads", isDirectory: true)

        try? createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        return downloadsDirectory
    }

    private nonisolated func realUserDownloadsDirectory() -> URL? {
        guard let password = getpwuid(getuid()), let home = password.pointee.pw_dir else {
            return nil
        }
        let homeURL = URL(fileURLWithPath: String(cString: home), isDirectory: true)
        let downloadsURL = homeURL.appendingPathComponent("Downloads", isDirectory: true)

        var isDirectory: ObjCBool = false
        guard fileExists(atPath: downloadsURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return downloadsURL
    }

    nonisolated func illuminateProfilesDirectory() -> URL {
        let profilesDirectory = illuminateAppSupportDirectory().appendingPathComponent("Profiles", isDirectory: true)
        try? createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
        return profilesDirectory
    }

    nonisolated func illuminateProfilesCatalogURL() -> URL {
        illuminateProfilesDirectory().appendingPathComponent("profiles.json")
    }

    nonisolated func illuminateProfileDirectory(profileID: UUID) -> URL {
        let directory = illuminateProfilesDirectory().appendingPathComponent(profileID.uuidString, isDirectory: true)
        try? createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
