//
//  CoordinatorScriptMessages.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import CoreLocation
import Foundation
import SwiftUI
import UserNotifications
import WebKit

extension WebViewRepresentable.Coordinator {
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping (Any?, String?) -> Void
        ) {
            self.userContentController(userContentController, didReceive: message)
            replyHandler(nil, nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case webScriptBridge.passwordBridgeName:
                guard message.frameInfo.isMainFrame else { return }
                handlePasswordMessage(message)
            case webScriptBridge.permissionBridgeName:
                guard message.frameInfo.isMainFrame else { return }
                handlePermissionMessage(message)
            case webScriptBridge.metadataBridgeName:
                handleMetadataMessage(message)
            case webScriptBridge.notificationBridgeName:
                handleNotificationMessage(message)
            default:
                break
            }
        }

        private func handleNotificationMessage(_ message: WKScriptMessage) {
            guard
                let body = message.body as? [String: Any],
                let type = body["type"] as? String,
                let webView = message.webView
            else { return }

            switch type {
            case "syncPermission":
                Task {
                    let status = await notificationService.getAuthorizationStatus()
                    await MainActor.run {
                        self.syncNotificationPermission(status, in: webView)
                    }
                }

            case "requestPermission":
                guard let requestID = body["id"] as? Int else { return }
                Task {
                    do {
                        let granted = try await notificationService.requestAuthorization()
                        let status: UNAuthorizationStatus = granted ? .authorized : .denied
                        await MainActor.run {
                            self.respondToNotificationPermissionRequest(requestID, status: status, in: webView)
                        }
                    } catch {
                        await MainActor.run {
                            self.respondToNotificationPermissionRequest(requestID, status: .denied, in: webView)
                        }
                    }
                }

            case "send":
                guard
                    let title = body["title"] as? String,
                    let bodyText = body["body"] as? String
                else { return }
                let tag = body["tag"] as? String
                
                Task {
                    try? await notificationService.sendNotification(title: title, body: bodyText, identifier: tag)
                }

            default:
                break
            }
        }

        private func syncNotificationPermission(_ status: UNAuthorizationStatus, in webView: WKWebView) {
            let jsStatus = webNotificationStatus(for: status)
            webView.evaluateJavaScript("if (typeof window.__illuminateNotificationSyncPermission === 'function') window.__illuminateNotificationSyncPermission('\(jsStatus)');")
        }

        private func respondToNotificationPermissionRequest(_ requestID: Int, status: UNAuthorizationStatus, in webView: WKWebView) {
            let jsStatus = webNotificationStatus(for: status)
            webView.evaluateJavaScript("if (typeof window.__illuminateNotificationResult === 'function') window.__illuminateNotificationResult(\(requestID), '\(jsStatus)');")
        }

        private func webNotificationStatus(for status: UNAuthorizationStatus) -> String {
            switch status {
            case .authorized, .provisional, .ephemeral:
                return "granted"
            case .denied:
                return "denied"
            case .notDetermined:
                return "default"
            @unknown default:
                return "default"
            }
        }

        private func handleMetadataMessage(_ message: WKScriptMessage) {
            guard
                let body = message.body as? [String: Any],
                let kind = MetadataMessageKind(rawValue: body["type"] as? String ?? "")
            else { return }

            switch kind {
            case .hover:
                handleHoverMetadata(body, webView: message.webView)
            case .page:
                handlePageMetadata(body, webView: message.webView)
            }
        }

        private func handleHoverMetadata(_ body: [String: Any], webView: WKWebView?) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let tab = self.tab else { return }

                if let hoverURL = body["hoverURL"] as? String, !hoverURL.isEmpty {
                    if tab.hoveredLinkURLString != hoverURL { tab.hoveredLinkURLString = hoverURL }
                    if let url = URL(string: hoverURL) {
                        self.preconnectManager.preconnect(to: url, in: webView)
                    }
                } else if tab.hoveredLinkURLString != nil {
                    tab.hoveredLinkURLString = nil
                }
            }
        }

        private func handlePageMetadata(_ body: [String: Any], webView: WKWebView?) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let tab = self.tab else { return }

                if let pageURLString = body["pageURL"] as? String,
                   let pageURL = URL(string: pageURLString),
                   tab.url != pageURL {
                    tab.url = pageURL
                    if tab.id == self.tabManager.activeTabID {
                        self.tabManager.syncActiveTabURL()
                    }
                }

                if let title = body["title"] as? String, !title.isEmpty, tab.title != title {
                    tab.title = title
                    if let url = tab.url {
                        self.historyManager.updateMetadata(for: url, title: title)
                    }
                }

                if let hex = body["themeColor"] as? String {
                    let newColor = Color(hex: hex)
                    if tab.themeColor != newColor { tab.themeColor = newColor }
                }

                guard
                    let faviconString = body["favicon"] as? String,
                    let faviconURL = self.resolveFaviconURL(from: faviconString, pageURL: webView?.url),
                    faviconURL != self.lastAppliedFaviconURL
                else { return }
                self.lastAppliedFaviconURL = faviconURL

                Task {
                    await self.loadFavicon(from: faviconURL, for: tab)
                    if let pageURL = webView?.url {
                        await MainActor.run {
                            self.historyManager.updateMetadata(for: pageURL, title: tab.title, faviconURL: faviconURL)
                        }
                    }
                }
            }
        }

        private func handlePasswordMessage(_ message: WKScriptMessage) {
            guard
                let body = message.body as? [String: Any],
                let type = body["type"] as? String,
                let url = message.webView?.url?.absoluteString
            else { return }

            switch type {
            case "savePassword":
                guard
                    let username = body["username"] as? String,
                    let password = body["password"] as? String
                else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.passwordService.savePassword(url: url, username: username, passwordData: password)
                }

            case "fieldsDetected":
                let service = passwordService
                Task { @MainActor [weak self] in
                    guard let self, let webView = message.webView else { return }
                    
                    // do we have passwords
                    guard service.hasPasswords(for: url) else { return }
                    
                    // 2. get auth
                    let authenticated = await service.authenticate()
                    guard authenticated else { return }
                    
                    // 3. fetch :)
                    let passwords = service.fetchPasswords(for: url)
                    guard let first = passwords.first else { return }
                    
                    let payload: [String: String] = ["username": first.username, "password": first.passwordData]
                    guard
                        let data = try? JSONEncoder().encode(payload),
                        let json = String(data: data, encoding: .utf8)
                    else { return }
                    let script = """
                    (() => {
                        const c = \(json);
                        const pass = document.querySelector('input[type="password"]');
                        const user = document.querySelector(
                            'input[autocomplete="username"], ' +
                            'input[autocomplete="email"], ' +
                            'input[name*="user"], ' +
                            'input[name*="login"], ' +
                            'input[name*="email"], ' +
                            'input[type="email"], ' +
                            'input[type="text"], ' +
                            'input[type="tel"], ' +
                            'input:not([type])'
                        );

                        const highlight = (el) => {
                            if (!el) return;
                            el.style.transition = 'all 0.5s ease-in-out';
                            el.style.backgroundColor = '#fdf2d5'; // Light gold
                            el.style.boxShadow = '0 0 10px rgba(255, 215, 0, 0.5)';
                            el.style.borderColor = '#ffd700';
                            
                            setTimeout(() => {
                                el.style.backgroundColor = '';
                                el.style.boxShadow = '';
                                el.style.borderColor = '';
                            }, 2000);
                        };

                        const fill = (el, val) => {
                            if (!el) return;
                            el.value = val;
                            el.dispatchEvent(new Event('input', { bubbles: true }));
                            el.dispatchEvent(new Event('change', { bubbles: true }));
                            highlight(el);
                        };

                        fill(pass, c.password);
                        fill(user, c.username);
                    })();
                    """
                    _ = try? await webView.evaluateJavaScript(script)
                }

            default:
                break
            }
        }

        private func handlePermissionMessage(_ message: WKScriptMessage) {
            guard
                let body = message.body as? [String: Any],
                body["type"] as? String == "location",
                let requestID = body["id"] as? Int,
                let webView = message.webView,
                let url = webView.url
            else { return }

            let origin = displayOrigin(for: url)
            websitePermissionService.requestPermission(for: origin, types: [.location]) { [weak self, weak webView] decision in
                guard let self, let webView else { return }
                guard decision == .allow else {
                    self.respondToLocationRequest(requestID, error: "Location access was blocked.", in: webView)
                    return
                }
                self.locationService.requestLocation { result in
                    switch result {
                    case .success(let location):
                        self.respondToLocationRequest(requestID, location: location, in: webView)
                    case .failure:
                        self.respondToLocationRequest(requestID, error: "Location access is unavailable.", in: webView)
                    }
                }
            }
        }

        func respondToLocationRequest(_ requestID: Int, location: CLLocation, in webView: WKWebView) {
            let coordinate = location.coordinate
            let payload: [String: Double] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "accuracy": location.horizontalAccuracy,
                "timestamp": location.timestamp.timeIntervalSince1970 * 1000
            ]
            guard payload.values.allSatisfy(\.isFinite),
                  let data = try? JSONEncoder().encode(payload),
                  let json = String(data: data, encoding: .utf8)
            else {
                respondToLocationRequest(requestID, error: "Location access is unavailable.", in: webView)
                return
            }
            webView.evaluateJavaScript(
                "if (typeof window.__illuminateLocationResult === 'function') window.__illuminateLocationResult(\(requestID), \(json));"
            )
        }

        func respondToLocationRequest(_ requestID: Int, error: String, in webView: WKWebView) {
            guard let json = try? String(data: JSONEncoder().encode(error), encoding: .utf8) else { return }
            webView.evaluateJavaScript("if (typeof window.__illuminateLocationResult === 'function') window.__illuminateLocationResult(\(requestID), { error: \(json) });")
        }

}
