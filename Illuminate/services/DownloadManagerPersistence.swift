//
//  DownloadManager+Persistence.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/4/26.
//

import Foundation

extension DownloadManager {
    func setRevealInFinderWhenFinished(_ enabled: Bool) {
        var updated = preferences
        updated.revealInFinderWhenFinished = enabled
        persistPreferences(updated)
    }

    func setAskWhereToSave(_ enabled: Bool) {
        var updated = preferences
        updated.askWhereToSave = enabled
        persistPreferences(updated)
    }

    func setLastPickedDirectory(_ directoryURL: URL) {
        guard directoryURL.hasDirectoryPath || directoryURL.pathExtension.isEmpty else { return }

        let resolvedDirectory = directoryURL.hasDirectoryPath ? directoryURL : directoryURL.deletingLastPathComponent()

        do {
            let bookmarkData = try resolvedDirectory.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            var updated = preferences
            updated.lastPickedDirectoryBookmarkData = bookmarkData
            AppLog.download("Stored last-picked download directory path=\(resolvedDirectory.path)")
            persistPreferences(updated)
        } catch {
            AppLog.download("Failed to store last-picked directory path=\(resolvedDirectory.path) error=\(error.localizedDescription)")
        }
    }

    func resolvedLastPickedDirectory() -> URL? {
        guard let bookmarkData = preferences.lastPickedDirectoryBookmarkData else {
            return nil
        }

        var isStale = false

        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            _ = resolvedURL.startAccessingSecurityScopedResource()

            if isStale {
                setLastPickedDirectory(resolvedURL)
            }

            return resolvedURL
        } catch {
            AppLog.download("Failed to resolve last-picked directory error=\(error.localizedDescription)")
            return nil
        }
    }

    func setDownloadDirectory(_ directoryURL: URL) {
        guard directoryURL.hasDirectoryPath else { return }

        do {
            try ensureDirectoryExists(at: directoryURL)

            let bookmarkData = try directoryURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            var updated = preferences
            updated.saveLocationBookmarkData = bookmarkData
            AppLog.download("Stored custom download directory path=\(directoryURL.path)")
            persistPreferences(updated)
        } catch {
            AppLog.download("Failed to store custom download directory path=\(directoryURL.path) error=\(error.localizedDescription)")
        }
    }

    func resetDownloadDirectory() {
        var updated = preferences
        updated.saveLocationBookmarkData = nil
        AppLog.download("Reset custom download directory to default path=\(fileManager.illuminateDownloadsDirectory().path)")
        persistPreferences(updated)
    }

    func persistPreferences(_ updated: DownloadPreferences) {
        preferences = updated
        downloadDirectoryURL = resolvedDownloadDirectory(from: updated)
        AppLog.download("Persisted download preferences revealWhenFinished=\(updated.revealInFinderWhenFinished) activeDirectory=\(downloadDirectoryURL.path)")
        if let data = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: preferencesKey)
        }
    }

    func resolvedDownloadDirectory(from preferences: DownloadPreferences) -> URL {
        guard let bookmarkData = preferences.saveLocationBookmarkData else {
            return fileManager.illuminateDownloadsDirectory()
        }

        var isStale = false

        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            _ = resolvedURL.startAccessingSecurityScopedResource()
            try ensureDirectoryExists(at: resolvedURL)
            AppLog.download("Resolved custom download directory path=\(resolvedURL.path) stale=\(isStale)")

            if isStale {
                setDownloadDirectory(resolvedURL)
            }

            return resolvedURL
        } catch {
            AppLog.download("Failed to resolve custom download directory error=\(error.localizedDescription); falling back to default path=\(fileManager.illuminateDownloadsDirectory().path)")
            return fileManager.illuminateDownloadsDirectory()
        }
    }

    func downloadStagingDirectoryURL() -> URL {
        let directory = fileManager
            .illuminateAppSupportDirectory()
            .appendingPathComponent("DownloadStaging", isDirectory: true)

        do {
            try ensureDirectoryExists(at: directory)
        } catch {
            AppLog.download("Failed to create download staging directory path=\(directory.path) error=\(error.localizedDescription)")
        }

        return directory
    }
}
