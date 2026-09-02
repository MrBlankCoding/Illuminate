//
//  DownloadManagerTransfersDelegates.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/2/26.
//

import AppKit
import Foundation
import WebKit

extension DownloadManager: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard let id = webKitDownloadIDs[ObjectIdentifier(download)] else {
            completionHandler(nil)
            return
        }

        let filename = resolvedFilename(suggestedFilename, fallbackURL: download.originalRequest?.url, mimeType: response.mimeType)
        let finalDestinationURL = uniqueDestinationURL(in: downloadDirectoryURL, preferredFilename: filename)
        let stagingDestinationURL = uniqueDestinationURL(in: downloadStagingDirectoryURL(), preferredFilename: filename)
        webKitStagingURLsByID[id] = stagingDestinationURL

        updateTask(id) { task in
            task.filename = finalDestinationURL.lastPathComponent
            task.destinationURL = finalDestinationURL
            task.totalBytesExpected = response.expectedContentLength > 0 ? response.expectedContentLength : nil
            task.state = .downloading
        }
        completionHandler(stagingDestinationURL)
    }

    func download(_ download: WKDownload, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = webKitDownloadIDs[ObjectIdentifier(download)] else { return }
        updateTask(id) { task in
            task.state = .downloading
            task.bytesWritten = totalBytesWritten
            task.totalBytesExpected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
            if totalBytesExpectedToWrite > 0 {
                task.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let id = webKitDownloadIDs.removeValue(forKey: ObjectIdentifier(download)) else { return }
        webKitDownloadsByID.removeValue(forKey: id)
        guard let destinationURL = downloads.first(where: { $0.id == id })?.destinationURL,
              let stagingURL = webKitStagingURLsByID.removeValue(forKey: id) else {
            failDownload(id: id, error: NSError(domain: "DownloadManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download finished without a destination."]))
            return
        }

        do {
            try moveDownload(at: stagingURL, to: destinationURL)
            finishDownload(id: id, destinationURL: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            failDownload(id: id, error: error)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let id = webKitDownloadIDs.removeValue(forKey: ObjectIdentifier(download)) else { return }
        webKitDownloadsByID.removeValue(forKey: id)
        webKitDownloadWebViews.removeValue(forKey: id)
        if let stagingURL = webKitStagingURLsByID.removeValue(forKey: id) {
            try? FileManager.default.removeItem(at: stagingURL)
        }
        failDownload(id: id, error: error, resumeData: resumeData, resumeRequiresWebKit: true)
    }

    func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func download(_ download: WKDownload, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}

extension DownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            guard let id = self.sessionTaskIDs[downloadTask.taskIdentifier] else { return }
            self.updateTask(id) { task in
                task.state = .downloading
                task.bytesWritten = totalBytesWritten
                task.totalBytesExpected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
                if totalBytesExpectedToWrite > 0 {
                    task.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let stagingURL = self.stageDownloadedFile(at: location)
        Task { @MainActor in
            guard let id = self.sessionTaskIDs[downloadTask.taskIdentifier] else {
                if let stagingURL { try? FileManager.default.removeItem(at: stagingURL) }
                return
            }
            let currentTask = self.downloads.first(where: { $0.id == id })
            let destinationURL = currentTask?.destinationURL ?? self.uniqueDestinationURL(in: self.downloadDirectoryURL, preferredFilename: self.resolvedFilename(downloadTask.response?.suggestedFilename ?? currentTask?.filename, fallbackURL: downloadTask.originalRequest?.url, mimeType: downloadTask.response?.mimeType))
            let sourceURL = stagingURL ?? location
            do {
                try self.moveDownload(at: sourceURL, to: destinationURL)
                self.finishDownload(id: id, destinationURL: destinationURL)
            } catch {
                if let stagingURL { try? FileManager.default.removeItem(at: stagingURL) }
                self.failDownload(id: id, error: error, resumeData: (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            guard let id = self.sessionTaskIDs.removeValue(forKey: task.taskIdentifier) else { return }
            self.sessionTasksByID.removeValue(forKey: id)
            guard let error else { return }
            if (error as NSError).code == NSURLErrorCancelled {
                self.updateTask(id) { task in
                    if task.state != .completed {
                        task.state = .cancelled
                        task.finishedAt = Date()
                    }
                }
            } else {
                self.failDownload(id: id, error: error)
            }
        }
    }
}
