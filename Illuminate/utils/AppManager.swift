//
//  AppManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation

extension Notification.Name {
    static let newTab = Notification.Name("app.newTab")
    static let focusURLBar = Notification.Name("app.focusURLBar")
    static let focusNewTabSearchBar = Notification.Name("app.focusNewTabSearchBar")
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
    static let zoomChanged = Notification.Name("app.zoomChanged")
    static let toggleFullScreen = Notification.Name("app.toggleFullScreen")
    static let closeActiveTab = Notification.Name("app.closeActiveTab")
    static let closeAllTabs = Notification.Name("app.closeAllTabs")
}

extension FileManager {
    func illuminateAppSupportDirectory() -> URL {
        let baseDirectory = urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        let appDirectory = baseDirectory.appendingPathComponent("Illuminate", isDirectory: true)
        try? createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
    }

    func illuminateDownloadsDirectory() -> URL {
        let downloadsDirectory = urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? temporaryDirectory.appendingPathComponent("Downloads", isDirectory: true)

        try? createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        return downloadsDirectory
    }

    func illuminateProfilesDirectory() -> URL {
        let profilesDirectory = illuminateAppSupportDirectory().appendingPathComponent("Profiles", isDirectory: true)
        try? createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
        return profilesDirectory
    }

    func illuminateProfilesCatalogURL() -> URL {
        illuminateProfilesDirectory().appendingPathComponent("profiles.json")
    }

    func illuminateProfileDirectory(profileID: UUID) -> URL {
        let directory = illuminateProfilesDirectory().appendingPathComponent(profileID.uuidString, isDirectory: true)
        try? createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
