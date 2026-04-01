//
//  WebScriptBridge.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import WebKit

final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

@MainActor
final class WebScriptBridge {

    static let shared = WebScriptBridge()
    private init() {}
    let metadataBridgeName = "metadataBridge"
    let passwordBridgeName = "passwordBridge"

    func installScripts(
        on contentController: WKUserContentController,
        handler: WKScriptMessageHandler,
        colorScheme: String
    ) {
        removeAll(from: contentController)

        let weakHandler = WeakScriptMessageHandler(handler)
        contentController.add(weakHandler, name: metadataBridgeName)
        contentController.add(weakHandler, name: passwordBridgeName)

        contentController.addUserScript(browserThemeSyncScript(colorScheme: colorScheme))
        contentController.addUserScript(metadataExtractionScript())
        contentController.addUserScript(hoverTrackingScript())
        contentController.addUserScript(passwordScript())
    }

    func removeAll(from contentController: WKUserContentController) {
        contentController.removeAllUserScripts()
        contentController.removeScriptMessageHandler(forName: metadataBridgeName)
        contentController.removeScriptMessageHandler(forName: passwordBridgeName)
    }

    private func metadataExtractionScript() -> WKUserScript {
        let source = """
        (() => {
            const faviconEl = document.querySelector('link[rel~="icon"]');
            const themeEl   = document.querySelector('meta[name="theme-color"]');
            try {
                window.webkit.messageHandlers.\(metadataBridgeName).postMessage({
                    favicon:    faviconEl ? faviconEl.href    : null,
                    themeColor: themeEl   ? themeEl.content  : null,
                    title:      document.title
                });
            } catch (_) {}
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }

    private func browserThemeSyncScript(colorScheme: String) -> WKUserScript {
        let source = """
        (() => {
            const scheme = "\(colorScheme)";
            const prefersDark = scheme === "dark";

            if (!window.__illuminateThemeSync) {
                const originalMatchMedia = window.matchMedia.bind(window);
                const listeners = new Set();

                const makeEntry = (query, darkQuery) => {
                    const entry = {
                        media: query,
                        onchange: null,
                        listeners: new Set(),
                        legacyListeners: new Set(),
                        get matches() { return darkQuery ? window.__illuminateThemeSync.prefersDark : !window.__illuminateThemeSync.prefersDark; },
                        addEventListener(type, listener) {
                            if (type === "change" && listener) this.listeners.add(listener);
                        },
                        removeEventListener(type, listener) {
                            if (type === "change" && listener) this.listeners.delete(listener);
                        },
                        addListener(listener) {
                            if (listener) this.legacyListeners.add(listener);
                        },
                        removeListener(listener) {
                            if (listener) this.legacyListeners.delete(listener);
                        },
                        dispatch() {
                            const event = { matches: this.matches, media: this.media };
                            this.listeners.forEach((listener) => {
                                try { listener.call(this, event); } catch (_) {}
                            });
                            this.legacyListeners.forEach((listener) => {
                                try { listener.call(this, event); } catch (_) {}
                            });
                            if (typeof this.onchange === "function") {
                                try { this.onchange.call(this, event); } catch (_) {}
                            }
                        }
                    };
                    listeners.add(entry);
                    return entry;
                };

                window.__illuminateThemeSync = {
                    originalMatchMedia,
                    listeners,
                    prefersDark
                };

                window.matchMedia = (query) => {
                    if (typeof query === "string") {
                        const normalized = query.replace(/\\s+/g, "").toLowerCase();
                        if (normalized === "(prefers-color-scheme:dark)") {
                            return makeEntry(query, true);
                        }
                        if (normalized === "(prefers-color-scheme:light)") {
                            return makeEntry(query, false);
                        }
                    }
                    return originalMatchMedia(query);
                };
            } else {
                window.__illuminateThemeSync.prefersDark = prefersDark;
            }

            document.documentElement.style.colorScheme = scheme;

            window.__illuminateThemeSync.listeners.forEach((entry) => entry.dispatch());
            window.dispatchEvent(new CustomEvent("illuminatecolorschemechange", { detail: { scheme } }));
        })();
        """

        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    private func hoverTrackingScript() -> WKUserScript {
        let source = """
        (() => {
            if (window.__illuminateHoverInstalled) return;
            window.__illuminateHoverInstalled = true;

            function postHover(value) {
                if (value === window.__illuminateLastHover) return;
                window.__illuminateLastHover = value;
                try {
                    window.webkit.messageHandlers.\(metadataBridgeName).postMessage({ hoverURL: value });
                } catch (_) {}
            }

            document.addEventListener('mouseover', (e) => {
                const link = e.target?.closest?.('a[href]');
                postHover(link ? link.href : null);
            }, { passive: true });

            document.addEventListener('mouseout', (e) => {
                if (!e.relatedTarget?.closest?.('a[href]')) postHover(null);
            }, { passive: true });
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    private func passwordScript() -> WKUserScript {
        let source = """
        (() => {
            if (window.__illuminatePasswordInstalled) return;
            window.__illuminatePasswordInstalled = true;

            function notifyFieldsDetected() {
                try {
                    window.webkit.messageHandlers.\(passwordBridgeName).postMessage({ type: 'fieldsDetected' });
                } catch (_) {}
            }

            function checkForPasswordFields() {
                if (document.querySelector('input[type="password"]')) {
                    notifyFieldsDetected();
                }
            }

            checkForPasswordFields();
            const observer = new MutationObserver(() => checkForPasswordFields());
            observer.observe(document.body, { childList: true, subtree: true });

            document.addEventListener('submit', (e) => {
                const form = e.target;
                const passwordField = form.querySelector('input[type="password"]');
                const userField     = form.querySelector(
                    'input[type="text"], input[type="email"], input:not([type])'
                );
                if (!passwordField || !userField) return;

                try {
                    window.webkit.messageHandlers.\(passwordBridgeName).postMessage({
                        type:     'savePassword',
                        username: userField.value,
                        password: passwordField.value
                    });
                } catch (_) {}
            }, true);
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    }
}
