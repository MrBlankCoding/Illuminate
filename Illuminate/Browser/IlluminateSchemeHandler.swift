//
//  IlluminateSchemeHandler.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/13/26.
//

import Foundation
import WebKit

class IlluminateSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        
        guard let illuminatePage = IlluminatePage(url: url) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        
        switch illuminatePage {
        case .newPage:
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>New Tab</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f0f0f0; color: #333; }
                    h1 { font-size: 3em; }
                </style>
            </head>
            <body>
                <h1>New Tab</h1>
            </body>
            </html>
            """
            
            if let data = htmlContent.data(using: .utf8) {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=utf-8"])
                urlSchemeTask.didReceive(response!)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } else {
                urlSchemeTask.didFailWithError(URLError(.unknown))
            }
        default:
            // Handle other IlluminatePages if needed, for now just fail
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // No-op for now, as we're serving static content
    }
}
