//
//  DownloadManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import AppKit
import Combine
import Foundation
import WebKit

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    static let downloadsDidChangeNotification = Notification.Name("DownloadManager.downloadsDidChange")

    var downloads: [DownloadTask] = []
    var downloadIndexMap: [UUID: Int] = [:]
    @Published var preferences: DownloadPreferences
    @Published var downloadDirectoryURL: URL
    @Published private(set) var hasRecentCompletedDownload = false
    var notificationThrottleTask: Task<Void, Never>?

    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 12
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    var sessionTaskIDs: [Int: UUID] = [:]
    var sessionTasksByID: [UUID: URLSessionDownloadTask] = [:]
    var webKitDownloadIDs: [ObjectIdentifier: UUID] = [:]
    var webKitDownloadsByID: [UUID: WKDownload] = [:]
    var webKitStagingURLsByID: [UUID: URL] = [:]
    private var completionIndicatorResetTask: Task<Void, Never>?

    let preferencesKey = "download.preferences"

    override init() {
        if
            let data = UserDefaults.standard.data(forKey: preferencesKey),
            let stored = try? JSONDecoder().decode(DownloadPreferences.self, from: data)
        {
            self.preferences = stored
        } else {
            self.preferences = DownloadPreferences()
        }

        self.downloadDirectoryURL = FileManager.default.illuminateDownloadsDirectory()

        super.init()
        downloadDirectoryURL = resolvedDownloadDirectory(from: preferences)
    }

    var hasVisibleDownloads: Bool {
        !downloads.isEmpty
    }

    func noteCompletedDownload() {
        completionIndicatorResetTask?.cancel()
        hasRecentCompletedDownload = true
        notifyDownloadsDidChange()

        completionIndicatorResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.clearRecentCompletedDownloadIndicator()
            }
        }
    }

    func acknowledgeRecentCompletedDownload() {
        completionIndicatorResetTask?.cancel()
        completionIndicatorResetTask = nil
        clearRecentCompletedDownloadIndicator()
    }

    private func clearRecentCompletedDownloadIndicator() {
        guard hasRecentCompletedDownload else { return }
        hasRecentCompletedDownload = false
        notifyDownloadsDidChange()
    }
}
