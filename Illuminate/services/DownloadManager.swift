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
        
        if Thread.isMainThread {
            self.downloads.append(task)
            notifyDownloadsDidChange()
        } else {
            DispatchQueue.main.sync {
                self.downloads.append(task)
                self.notifyDownloadsDidChange()
            }
        }
        
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
        let filename: String
        
        if let suggested = suggestedFilename, !suggested.isEmpty {
            filename = suggested
        } else {
            let last = url.lastPathComponent
            filename = last.isEmpty ? "download" : last
        }
        
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
        
        if Thread.isMainThread {
            self.downloads.append(task)
            notifyDownloadsDidChange()
        } else {
            DispatchQueue.main.sync {
                self.downloads.append(task)
                self.notifyDownloadsDidChange()
            }
        }
        
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
            let suggestedName = (response?.suggestedFilename).flatMap { $0.isEmpty ? nil : $0 } ?? filename
            var destinationURL = downloadsFolder.appendingPathComponent(suggestedName)
            var counter = 1
            
            while fileManager.fileExists(atPath: destinationURL.path) {
                let name = (suggestedName as NSString).deletingPathExtension
                let ext = (suggestedName as NSString).pathExtension
                destinationURL = downloadsFolder.appendingPathComponent("\(name) (\(counter)).\(ext)")
                counter += 1
            }
            
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
        let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        
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
        
        if Thread.isMainThread {
            self.downloads.append(task)
            notifyDownloadsDidChange()
        } else {
            DispatchQueue.main.sync {
                self.downloads.append(task)
                self.notifyDownloadsDidChange()
            }
        }
        
        download.delegate = self
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
        let fileManager = FileManager.default
        let downloadsFolder = fileManager.illuminateDownloadsDirectory()
        let destinationURL = downloadsFolder.appendingPathComponent(suggestedFilename)
        var finalURL = destinationURL
        var counter = 1
        while fileManager.fileExists(atPath: finalURL.path) {
            let name = (suggestedFilename as NSString).deletingPathExtension
            let ext = (suggestedFilename as NSString).pathExtension
            finalURL = downloadsFolder.appendingPathComponent("\(name) (\(counter)).\(ext)")
            counter += 1
        }
        
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
