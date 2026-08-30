//
//  DownloadManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import AppKit
import Foundation
import Observation
import WebKit

@MainActor
final class WeakWKWebViewBox {
    weak var webView: WKWebView?
    init(_ webView: WKWebView?) { self.webView = webView }
}

@MainActor
@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()


    var downloads: [DownloadTask] = []
    @ObservationIgnored var downloadIndexMap: [UUID: Int] = [:]
    var preferences: DownloadPreferences
    var downloadDirectoryURL: URL
    private(set) var hasRecentCompletedDownload = false
    private(set) var hasSessionDownload = false
    @ObservationIgnored var notificationThrottleTask: Task<Void, Never>?

    @ObservationIgnored lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 12
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    @ObservationIgnored var sessionTaskIDs: [Int: UUID] = [:]
    @ObservationIgnored var sessionTasksByID: [UUID: URLSessionDownloadTask] = [:]
    @ObservationIgnored var webKitDownloadIDs: [ObjectIdentifier: UUID] = [:]
    @ObservationIgnored var webKitDownloadsByID: [UUID: WKDownload] = [:]
    @ObservationIgnored var webKitDownloadWebViews: [UUID: WeakWKWebViewBox] = [:]
    @ObservationIgnored var webKitStagingURLsByID: [UUID: URL] = [:]
    @ObservationIgnored var taskProfileIDs: [UUID: UUID] = [:]
    @ObservationIgnored private var completionIndicatorResetTask: Task<Void, Never>?

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

    var hasActiveDownloads: Bool {
        downloads.contains(where: \.isActive)
    }

    func markSessionHasDownload() {
        hasSessionDownload = true
    }

    func recordInProfileHistory(_ task: DownloadTask) {
        guard let profileID = taskProfileIDs[task.id],
              let store = DownloadHistoryRegistry.shared.store(for: profileID) else { return }
        store.record(task)
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
