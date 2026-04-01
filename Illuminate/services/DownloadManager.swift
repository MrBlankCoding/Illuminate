//
//  DownloadManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import Foundation
import WebKit
import Combine
import AppKit
import UniformTypeIdentifiers

// still not working
// Idk what im missing
// seems like an app sandbox issue?
// but the entitlements look correct 

struct DownloadTask: Identifiable {
    let id: UUID
    let url: URL
    let filename: String
    var progress: Double
    var isCompleted: Bool
    var isFailed: Bool
    var error: Error?
    var destinationURL: URL?
    let download: WKDownload?
}

final class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate {
    static let shared = DownloadManager()
    static let downloadsDidChangeNotification = Notification.Name("DownloadManager.downloadsDidChange")
    
    @Published var downloads: [DownloadTask] = []
    
    private override init() {
        super.init()
    }

    private func notifyDownloadsDidChange() {
        NotificationCenter.default.post(
            name: Self.downloadsDidChangeNotification,
            object: self,
            userInfo: ["hasActiveDownloads": downloads.contains { !$0.isCompleted && !$0.isFailed }]
        )
    }

    private func sanitizedFilename(_ rawFilename: String?, fallbackURL: URL? = nil) -> String {
        let trimmed = rawFilename?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        if let trimmed, !trimmed.isEmpty, trimmed != ".", trimmed != ".." {
            return trimmed
        }

        if let fallbackURL {
            let candidate = fallbackURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return candidate
            }
        }

        return "download"
    }

    private func uniqueDestinationURL(in directory: URL, preferredFilename: String) -> URL {
        let fileManager = FileManager.default
        let safeFilename = sanitizedFilename(preferredFilename)
        var destinationURL = directory.appendingPathComponent(safeFilename, isDirectory: false)

        let name = (safeFilename as NSString).deletingPathExtension
        let ext = (safeFilename as NSString).pathExtension
        var counter = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            let duplicateName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            destinationURL = directory.appendingPathComponent(duplicateName, isDirectory: false)
            counter += 1
        }

        return destinationURL
    }

    private func filename(for sourceURL: URL?, suggestedFilename: String?, mimeType: String?) -> String {
        var filename = sanitizedFilename(suggestedFilename, fallbackURL: sourceURL)

        let pathExtension = (filename as NSString).pathExtension
        if pathExtension.isEmpty,
           let mimeType,
           let type = UTType(mimeType: mimeType),
           let preferredExtension = type.preferredFilenameExtension {
            filename.append(".\(preferredExtension)")
        }

        return filename
    }

    private func appendTask(_ task: DownloadTask) {
        if Thread.isMainThread {
            downloads.append(task)
            notifyDownloadsDidChange()
        } else {
            DispatchQueue.main.sync {
                self.downloads.append(task)
                self.notifyDownloadsDidChange()
            }
        }
    }
    
    func startDownload(from url: URL, to destinationURL: URL) {
        let id = UUID()
        let filename = destinationURL.lastPathComponent
        
        let task = DownloadTask(
            id: id,
            url: url,
            filename: filename,
            progress: 0,
            isCompleted: false,
            isFailed: false,
            error: nil,
            destinationURL: destinationURL,
            download: nil
        )
        
        appendTask(task)
        
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default)
        
        session.downloadTask(with: request) { [weak self] tempURL, _, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                        self.downloads[index].isFailed = true
                        self.downloads[index].error = error
                        self.notifyDownloadsDidChange()
                    }
                }
                return
            }
            
            guard let tempURL = tempURL else {
                return
            }
            
            let fileManager = FileManager.default
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempURL, to: destinationURL)
            } catch {
                DispatchQueue.main.async {
                    if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                        self.downloads[index].isFailed = true
                        self.downloads[index].error = error
                        self.notifyDownloadsDidChange()
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                    self.downloads[index].isCompleted = true
                    self.downloads[index].progress = 1.0
                    self.notifyDownloadsDidChange()
                }
            }
        }.resume()
    }
    
    func startDownload(from url: URL, suggestedFilename: String? = nil) {
        let id = UUID()
        let filename = sanitizedFilename(suggestedFilename, fallbackURL: url)
        
        let task = DownloadTask(
            id: id,
            url: url,
            filename: filename,
            progress: 0,
            isCompleted: false,
            isFailed: false,
            error: nil,
            destinationURL: nil,
            download: nil
        )
        
        appendTask(task)
        
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default)
        
        session.downloadTask(with: request) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                        self.downloads[index].isFailed = true
                        self.downloads[index].error = error
                        self.notifyDownloadsDidChange()
                    }
                }
                return
            }
            
            guard let tempURL = tempURL else {
                return
            }
            
            let fileManager = FileManager.default
            let downloadsFolder = fileManager.illuminateDownloadsDirectory()
            let suggestedName = self.sanitizedFilename(response?.suggestedFilename, fallbackURL: url)
            let destinationURL = self.uniqueDestinationURL(
                in: downloadsFolder,
                preferredFilename: suggestedName.isEmpty ? filename : suggestedName
            )
            
            do {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
            } catch {
                DispatchQueue.main.async {
                    if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                        self.downloads[index].isFailed = true
                        self.downloads[index].error = error
                        self.notifyDownloadsDidChange()
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                    self.downloads[index].destinationURL = destinationURL
                    self.downloads[index].isCompleted = true
                    self.downloads[index].progress = 1.0
                    self.notifyDownloadsDidChange()
                }
            }
        }.resume()
    }
    
    func addDownload(_ download: WKDownload) {
        let id = UUID()
        let url = download.originalRequest?.url ?? URL(string: "about:blank")!
        let filename = sanitizedFilename(nil, fallbackURL: url)
        
        let task = DownloadTask(
            id: id,
            url: url,
            filename: filename,
            progress: 0,
            isCompleted: false,
            isFailed: false,
            error: nil,
            destinationURL: nil,
            download: download
        )
        
        appendTask(task)
        
        download.delegate = self
    }

    func saveDownloadedData(
        _ data: Data,
        from sourceURL: URL?,
        suggestedFilename: String? = nil,
        mimeType: String? = nil
    ) {
        let destinationURL = uniqueDestinationURL(
            in: FileManager.default.illuminateDownloadsDirectory(),
            preferredFilename: filename(for: sourceURL, suggestedFilename: suggestedFilename, mimeType: mimeType)
        )
        saveDownloadedData(
            data,
            from: sourceURL,
            to: destinationURL,
            suggestedFilename: suggestedFilename,
            mimeType: mimeType
        )
    }

    func saveDownloadedData(
        _ data: Data,
        from sourceURL: URL?,
        to destinationURL: URL,
        suggestedFilename: String? = nil,
        mimeType: String? = nil
    ) {
        let id = UUID()
        let filename = filename(for: sourceURL, suggestedFilename: suggestedFilename, mimeType: mimeType)

        let task = DownloadTask(
            id: id,
            url: sourceURL ?? destinationURL,
            filename: destinationURL.lastPathComponent.isEmpty ? filename : destinationURL.lastPathComponent,
            progress: 0,
            isCompleted: false,
            isFailed: false,
            error: nil,
            destinationURL: destinationURL,
            download: nil
        )

        appendTask(task)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try data.write(to: destinationURL, options: .atomic)
                DispatchQueue.main.async {
                    if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                        self.downloads[index].isCompleted = true
                        self.downloads[index].progress = 1.0
                        self.notifyDownloadsDidChange()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                        self.downloads[index].isFailed = true
                        self.downloads[index].error = error
                        self.notifyDownloadsDidChange()
                    }
                }
            }
        }
    }

    func clearDownloads() {
        if Thread.isMainThread {
            self.downloads.removeAll()
            notifyDownloadsDidChange()
        } else {
            DispatchQueue.main.sync {
                self.downloads.removeAll()
                self.notifyDownloadsDidChange()
            }
        }
    }
    
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let downloadsFolder = FileManager.default.illuminateDownloadsDirectory()
        let originalURL = download.originalRequest?.url
        let resolvedFilename = sanitizedFilename(suggestedFilename, fallbackURL: originalURL)
        let finalURL = uniqueDestinationURL(in: downloadsFolder, preferredFilename: resolvedFilename)
        
        DispatchQueue.main.async {
            if let index = self.downloads.firstIndex(where: { $0.download === download }) {
                self.downloads[index].destinationURL = finalURL
                self.notifyDownloadsDidChange()
            }
        }
        
        completionHandler(finalURL)
    }
    
    func download(_ download: WKDownload, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            if let index = self.downloads.firstIndex(where: { $0.download === download }) {
                self.downloads[index].progress = progress
                self.notifyDownloadsDidChange()
            }
        }
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        DispatchQueue.main.async {
            if let index = self.downloads.firstIndex(where: { $0.download === download }) {
                self.downloads[index].isCompleted = true
                self.downloads[index].progress = 1.0
                self.notifyDownloadsDidChange()
            }
        }
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        DispatchQueue.main.async {
            if let index = self.downloads.firstIndex(where: { $0.download === download }) {
                self.downloads[index].isFailed = true
                self.downloads[index].error = error
                self.notifyDownloadsDidChange()
            }
        }
    }
    
    func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func download(_ download: WKDownload, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}
