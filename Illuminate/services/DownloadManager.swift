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

    @Published var downloads: [DownloadTask] = []
    @Published var preferences: DownloadPreferences
    @Published var downloadDirectoryURL: URL

    let fileManager: FileManager
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

    let preferencesKey = "download.preferences"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        if
            let data = UserDefaults.standard.data(forKey: preferencesKey),
            let stored = try? JSONDecoder().decode(DownloadPreferences.self, from: data)
        {
            self.preferences = stored
        } else {
            self.preferences = DownloadPreferences()
        }

        self.downloadDirectoryURL = fileManager.illuminateDownloadsDirectory()

        super.init()
        downloadDirectoryURL = resolvedDownloadDirectory(from: preferences)
    }

    var hasVisibleDownloads: Bool {
        !downloads.isEmpty
    }
}
