//
//  EaselURLSchemeHandler.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import WebKit
import UniformTypeIdentifiers

final class EaselURLSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil))
            return
        }

        let path = url.path // "/index.html" or "/bridge.js" etc.
        let _ = url.host ?? "easel"
        let resourceURL = Bundle.main.resourceURL!
        let candidates: [URL] = [
            resourceURL.appendingPathComponent(String(path.dropFirst())), // Resources/<path>
            resourceURL.appendingPathComponent("Easel/Resources\(path)"),
            resourceURL.appendingPathComponent("Resources\(path)"),
            resourceURL.appendingPathComponent(path) // absolute
        ]

        var fileURL: URL? = nil
        var fileData: Data? = nil
        for cand in candidates {
            if FileManager.default.fileExists(atPath: cand.path), let data = try? Data(contentsOf: cand) {
                fileURL = cand
                fileData = data
                break
            }
        }

        guard let data = fileData, let fileURL = fileURL else {
            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: ["Access-Control-Allow-Origin": "*"])!
            task.didReceive(resp)
            task.didFinish()
            return
        }

        let mime = mimeType(for: fileURL)
        let headers = [
            "Content-Type": mime,
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
            "Cache-Control": "no-cache"
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // no-op 
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if let uti = UTType(filenameExtension: ext), let mime = uti.preferredMIMEType { return mime }
        switch ext {
        case "html": return "text/html"
        case "js": return "application/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "png": return "image/png"
        case "svg": return "image/svg+xml"
        default: return "application/octet-stream"
        }
    }
}
