//
//  WebScriptBridge.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import WebKit

enum BridgeName: String, CaseIterable {
    case metadata = "metadataBridge"
    case password = "passwordBridge"
}

final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: (any WKScriptMessageHandler)?

    init(_ delegate: some WKScriptMessageHandler) {
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

    var metadataBridgeName: String { BridgeName.metadata.rawValue }
    var passwordBridgeName: String { BridgeName.password.rawValue }
    func installScripts(
        on contentController: WKUserContentController,
        handler: some WKScriptMessageHandler,
        colorScheme: String
    ) {
        removeAll(from: contentController)

        let weakHandler = WeakScriptMessageHandler(handler)
        for bridge in BridgeName.allCases {
            contentController.add(weakHandler, name: bridge.rawValue)
        }

        contentController.addUserScript(browserThemeSyncScript(colorScheme: colorScheme))
        contentController.addUserScript(hoverTrackingScript())
        contentController.addUserScript(passwordScript())
        contentController.addUserScript(metadataExtractionScript())
    }

    func removeAll(from contentController: WKUserContentController) {
        contentController.removeAllUserScripts()
        for bridge in BridgeName.allCases {
            contentController.removeScriptMessageHandler(forName: bridge.rawValue)
        }
    }

    private func metadataExtractionScript() -> WKUserScript {
        let source = """
        (() => {
            'use strict';
            const faviconEl   = document.querySelector('link[rel~="icon"]');
            const themeEl     = document.querySelector('meta[name="theme-color"]');
            const canonicalEl = document.querySelector('link[rel="canonical"]');
            try {
                window.webkit.messageHandlers.\(BridgeName.metadata.rawValue).postMessage({
                    favicon:      faviconEl   ? faviconEl.href    : null,
                    themeColor:   themeEl     ? themeEl.content   : null,
                    canonicalURL: canonicalEl ? canonicalEl.href  : null,
                    title:        document.title
                });
            } catch (_) {}
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    private func browserThemeSyncScript(colorScheme: String) -> WKUserScript {
        let safeScheme = (try? String(
            data: JSONEncoder().encode(colorScheme),
            encoding: .utf8
        )) ?? "\"light\""

        let source = """
        (() => {
            'use strict';
            const scheme     = \(safeScheme);
            const prefersDark = scheme === "dark";

            const sync = window.__illuminateThemeSync;

            if (!sync) {
                const originalMatchMedia = window.matchMedia.bind(window);
                const entries = new Set();
                function makeEntry(query, isDarkQuery) {
                    const entry = {
                        media:           query,
                        onchange:        null,
                        _listeners:      new Set(),
                        _legacyListeners: new Set(),

                        get matches() {
                            return isDarkQuery
                                ? window.__illuminateThemeSync.prefersDark
                                : !window.__illuminateThemeSync.prefersDark;
                        },

                        addEventListener(type, listener, _opts) {
                            if (type === "change" && typeof listener === "function")
                                this._listeners.add(listener);
                        },
                        removeEventListener(type, listener) {
                            if (type === "change") this._listeners.delete(listener);
                        },
                        /** @deprecated */
                        addListener(listener) {
                            if (typeof listener === "function")
                                this._legacyListeners.add(listener);
                        },
                        /** @deprecated */
                        removeListener(listener) {
                            this._legacyListeners.delete(listener);
                        },

                        dispatch() {
                            const event = { matches: this.matches, media: this.media };
                            for (const fn of this._listeners) {
                                try { fn.call(this, event); } catch (_) {}
                            }
                            for (const fn of this._legacyListeners) {
                                try { fn.call(this, event); } catch (_) {}
                            }
                            if (typeof this.onchange === "function") {
                                try { this.onchange.call(this, event); } catch (_) {}
                            }
                        }
                    };

                    entries.add(entry);
                    return entry;
                }

                window.__illuminateThemeSync = {
                    originalMatchMedia,
                    entries,
                    prefersDark
                };

                window.matchMedia = (query) => {
                    if (typeof query !== "string") return originalMatchMedia(query);
                    const n = query.replace(/\\s+/g, "").toLowerCase();
                    if (n === "(prefers-color-scheme:dark)")  return makeEntry(query, true);
                    if (n === "(prefers-color-scheme:light)") return makeEntry(query, false);
                    return originalMatchMedia(query);
                };

            } else {
                sync.prefersDark = prefersDark;
                for (const entry of sync.entries) entry.dispatch();
            }

            document.documentElement.style.colorScheme = scheme;
            window.dispatchEvent(
                new CustomEvent("illuminatecolorschemechange", { detail: { scheme } })
            );
        })();
        """

        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    private func hoverTrackingScript() -> WKUserScript {
        let source = """
        (() => {
            'use strict';
            if (window.__illuminateHoverInstalled) return;
            window.__illuminateHoverInstalled = true;

            let lastHover = null;

            function postHover(value) {
                if (value === lastHover) return;
                lastHover = value;
                try {
                    window.webkit.messageHandlers.\(BridgeName.metadata.rawValue).postMessage(
                        { hoverURL: value }
                    );
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
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    private func passwordScript() -> WKUserScript {
        let source = """
        (() => {
            'use strict';
            if (window.__illuminatePasswordInstalled) return;
            window.__illuminatePasswordInstalled = true;

            const bridge = () => window.webkit.messageHandlers.\(BridgeName.password.rawValue);

            function notifyFieldsDetected() {
                try { bridge().postMessage({ type: 'fieldsDetected' }); } catch (_) {}
            }

            function trySavePassword(username, password) {
                if (!username || !password) return;
                try {
                    bridge().postMessage({ type: 'savePassword', username, password });
                } catch (_) {}
            }

            function checkForPasswordFields() {
                if (document.querySelector('input[type="password"]')) {
                    notifyFieldsDetected();
                }
            }

            checkForPasswordFields();
            const observer = new MutationObserver(checkForPasswordFields);
            observer.observe(document.body ?? document.documentElement, {
                childList: true,
                subtree: true
            });

            document.addEventListener('submit', (e) => {
                const form = e.target;
                if (!(form instanceof HTMLFormElement)) return;

                const passwordField = form.querySelector('input[type="password"]');
                if (!passwordField) return;
                const userField = form.querySelector(
                    'input[type="email"], input[type="text"], input:not([type])'
                );
                if (!userField) return;

                trySavePassword(userField.value.trim(), passwordField.value);
            }, { capture: true });
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
}