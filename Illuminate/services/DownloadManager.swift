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

final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    static let downloadsDidChangeNotification = Notification.Name("DownloadManager.downloadsDidChange")

    @Published private(set) var downloads: [DownloadTask] = []
    @Published private(set) var preferences: DownloadPreferences
    @Published private(set) var downloadDirectoryURL: URL

    fileprivate let fileManager: FileManager
    fileprivate lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 12
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    fileprivate var sessionTaskIDs: [Int: UUID] = [:]
    fileprivate var sessionTasksByID: [UUID: URLSessionDownloadTask] = [:]
    fileprivate var webKitDownloadIDs: [ObjectIdentifier: UUID] = [:]
    fileprivate var webKitDownloadsByID: [UUID: WKDownload] = [:]
    fileprivate var webKitStagingURLsByID: [UUID: URL] = [:]

    fileprivate let preferencesKey = "download.preferences"

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
        self.downloadDirectoryURL = resolvedDownloadDirectory(from: self.preferences)
    }

    var hasVisibleDownloads: Bool {
        !downloads.isEmpty
    }
}
