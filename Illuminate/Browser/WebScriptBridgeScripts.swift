//
//  WebscriptBridgeScripts.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import WebKit

extension WebScriptBridge {
    // snapshot feature?
    func metadataExtractionScript() -> WKUserScript {
        let source = """
        (() => {
            'use strict';
            if (window.__illuminateMetadataInstalled) return;
            window.__illuminateMetadataInstalled = true;

            const bridge = () => \(BridgeName.metadata.jsAccessor);

            function currentSnapshot() {
                const faviconEl   = document.querySelector('link[rel~="icon"]');
                const themeEl     = document.querySelector('meta[name="theme-color"]');
                const canonicalEl = document.querySelector('link[rel="canonical"]');
                return {
                    type:         "\(MetadataMessageKind.page.rawValue)",
                    pageURL:      window.location.href,
                    favicon:      faviconEl   ? faviconEl.href    : null,
                    themeColor:   themeEl     ? themeEl.content   : null,
                    canonicalURL: canonicalEl ? canonicalEl.href  : null,
                    title:        document.title
                };
            }

            let lastSent = null;
            function post(snapshot) {
                const key = JSON.stringify(snapshot);
                if (key === lastSent) return;
                lastSent = key;
                try { bridge().postMessage(snapshot); } catch (_) {}
            }

            post(currentSnapshot());
            const titleEl = document.querySelector('title') ?? document.head;
            if (titleEl) {
                new MutationObserver(() => post(currentSnapshot()))
                    .observe(titleEl, { childList: true, characterData: true, subtree: true });
            }

            for (const method of ['pushState', 'replaceState']) {
                const original = history[method];
                history[method] = function (...args) {
                    const result = original.apply(this, args);
                    setTimeout(() => post(currentSnapshot()), 0);
                    return result;
                };
            }
            window.addEventListener('popstate', () => post(currentSnapshot()));
            window.addEventListener('hashchange', () => post(currentSnapshot()));
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    func hoverTrackingScript() -> WKUserScript {
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
                    \(BridgeName.metadata.jsAccessor).postMessage({ type: "\(MetadataMessageKind.hover.rawValue)", hoverURL: value });
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

    func locationPermissionScript() -> WKUserScript {
        let source = """
        (() => {
            'use strict';
            if (window.__illuminateLocationInstalled || !navigator.geolocation) return;
            window.__illuminateLocationInstalled = true;

            let nextID = 0;
            const callbacks = new Map();
            const bridge = () => \(BridgeName.permission.jsAccessor);

            window.__illuminateLocationResult = (id, result) => {
                const callback = callbacks.get(id);
                if (!callback) return;
                callbacks.delete(id);

                if (result.error) {
                    callback.failure({ code: 1, message: result.error });
                    return;
                }

                callback.success({
                    coords: {
                        latitude: result.latitude,
                        longitude: result.longitude,
                        accuracy: result.accuracy,
                        altitude: null,
                        altitudeAccuracy: null,
                        heading: null,
                        speed: null
                    },
                    timestamp: result.timestamp
                });
            };

            const request = (success, failure) => {
                const id = ++nextID;
                callbacks.set(id, { success, failure: failure || (() => {}) });
                try {
                    bridge().postMessage({ type: 'location', id });
                } catch (_) {
                    window.__illuminateLocationResult(id, { error: 'Location access is unavailable.' });
                }
                return id;
            };

            navigator.geolocation.getCurrentPosition = (success, failure, _options) => request(success, failure);
            navigator.geolocation.watchPosition = (success, failure, _options) => request(success, failure);
            navigator.geolocation.clearWatch = (id) => callbacks.delete(id);
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }

    func notificationScript() -> WKUserScript {
        let source = """
        (() => {
            'use strict';
            if (window.__illuminateNotificationInstalled) return;
            window.__illuminateNotificationInstalled = true;

            const bridge = () => \(BridgeName.notification.jsAccessor);
            let permissionStatus = 'default';

            window.__illuminateNotificationSyncPermission = (status) => {
                permissionStatus = status;
            };

            const callbacks = new Map();
            let nextID = 0;

            window.__illuminateNotificationResult = (id, result) => {
                const cb = callbacks.get(id);
                if (cb) {
                    callbacks.delete(id);
                    cb(result);
                }
            };

            class IlluminateNotification extends EventTarget {
                constructor(title, options = {}) {
                    super();
                    this.title = title;
                    this.body = options.body || '';
                    this.tag = options.tag || null;

                    if (permissionStatus === 'granted') {
                        try {
                            bridge().postMessage({
                                type: 'send',
                                title: this.title,
                                body: this.body,
                                tag: this.tag
                            });
                        } catch (_) {}
                    }
                }

                static get permission() {
                    return permissionStatus;
                }

                static requestPermission(callback) {
                    const id = ++nextID;
                    const promise = new Promise((resolve) => {
                        callbacks.set(id, (status) => {
                            permissionStatus = status;
                            if (callback) callback(status);
                            resolve(status);
                        });
                    });

                    try {
                        bridge().postMessage({ type: 'requestPermission', id });
                    } catch (_) {
                        window.__illuminateNotificationResult(id, 'denied');
                    }

                    return promise;
                }
            }

            window.Notification = IlluminateNotification;
            try { bridge().postMessage({ type: 'syncPermission' }); } catch (_) {}
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    func canvasFingerprintingProtectionScript() -> WKUserScript {
        let source = """
        (() => {
            'use strict';
            if (window.__illuminateCanvasProtectionInstalled) return;
            const captchaDomains = [
                'arkoselabs.com', 'captcha.com', 'cloudflare.com', 'friendlycaptcha.com',
                'funcaptcha.com', 'google.com', 'hcaptcha.com', 'recaptcha.net'
            ];
            const host = String(location.hostname || '').toLowerCase();
            if (captchaDomains.some(domain => host === domain || host.endsWith('.' + domain))) return;
            window.__illuminateCanvasProtectionInstalled = true;

            let seed = 0;
            const fingerprintSeed = String(location.hostname || location.origin || 'illuminate');
            for (let index = 0; index < fingerprintSeed.length; index++) {
                seed = ((seed << 5) - seed + fingerprintSeed.charCodeAt(index)) | 0;
            }
            const offset = (Math.abs(seed) % 3) + 1;

            const alter = (imageData) => {
                const pixels = imageData && imageData.data;
                if (!pixels || pixels.length < 4) return imageData;
                for (let index = offset * 97; index < pixels.length; index += 4093) {
                    pixels[index] = (pixels[index] + offset) & 255;
                }
                return imageData;
            };

            const contextPrototype = window.CanvasRenderingContext2D && window.CanvasRenderingContext2D.prototype;
            if (contextPrototype && contextPrototype.getImageData) {
                const originalGetImageData = contextPrototype.getImageData;
                contextPrototype.getImageData = function(...args) {
                    return alter(originalGetImageData.apply(this, args));
                };
            }

            const canvasPrototype = window.HTMLCanvasElement && window.HTMLCanvasElement.prototype;
            if (!canvasPrototype || !canvasPrototype.toDataURL) return;
            const originalToDataURL = canvasPrototype.toDataURL;
            canvasPrototype.toDataURL = function(...args) {
                const context = this.getContext && this.getContext('2d');
                if (!context || !this.width || !this.height) return originalToDataURL.apply(this, args);
                try {
                    const imageData = context.getImageData(0, 0, this.width, this.height);
                    const originalPixels = new Uint8ClampedArray(imageData.data);
                    alter(imageData);
                    context.putImageData(imageData, 0, 0);
                    const result = originalToDataURL.apply(this, args);
                    imageData.data.set(originalPixels);
                    context.putImageData(imageData, 0, 0);
                    return result;
                } catch (_) {
                    return originalToDataURL.apply(this, args);
                }
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    func passwordScript(colorScheme: String) -> WKUserScript {
        let isDark = colorScheme == "dark"
        let bgColor = isDark ? "#2a2a2a" : "white"
        let textColor = isDark ? "#eee" : "#333"
        let subColor = isDark ? "#aaa" : "#666"
        let borderColor = isDark ? "#444" : "#ddd"
        let hoverColor = isDark ? "#3a3a3a" : "#f5f5f5"
        let separatorColor = isDark ? "#444" : "#eee"

        let source = """
        (() => {
            'use strict';
            if (window.__illuminatePasswordInstalled) return;
            window.__illuminatePasswordInstalled = true;

            const bridge = () => \(BridgeName.password.jsAccessor);
            let lastFocusedElement = null;

            function notifyFieldsDetected() {
                try { bridge().postMessage({ type: 'fieldsDetected' }); } catch (_) {}
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

            document.addEventListener('focusin', (e) => {
                const el = e.target;
                if (el === lastFocusedElement) return;
                lastFocusedElement = el;

                if (el.tagName === 'INPUT' && (
                    el.type === 'password' ||
                    el.type === 'email' ||
                    el.type === 'text' ||
                    el.getAttribute('autocomplete')?.includes('username') ||
                    el.getAttribute('autocomplete')?.includes('email')
                )) {
                    const isLoginField = el.type === 'password' ||
                                       el.name?.toLowerCase().includes('user') ||
                                       el.name?.toLowerCase().includes('login') ||
                                       el.name?.toLowerCase().includes('email') ||
                                       el.id?.toLowerCase().includes('user') ||
                                       el.id?.toLowerCase().includes('login') ||
                                       el.id?.toLowerCase().includes('email');

                    if (isLoginField) {
                        const rect = el.getBoundingClientRect();
                        bridge().postMessage({
                            type: 'requestAutofillOptions',
                            rect: {
                                x: rect.left,
                                y: rect.top,
                                width: rect.width,
                                height: rect.height
                            }
                        });
                    }
                }
            }, true);

            document.addEventListener('focusout', (e) => {
                setTimeout(() => {
                    if (document.activeElement !== lastFocusedElement) {
                        lastFocusedElement = null;
                        const dropdown = document.getElementById('illuminate-autofill-dropdown');
                        if (dropdown) dropdown.remove();
                    }
                }, 200);
            }, true);

            window.__illuminateShowAutofillDropdown = (accounts, rect) => {
                let dropdown = document.getElementById('illuminate-autofill-dropdown');
                if (dropdown) dropdown.remove();

                dropdown = document.createElement('div');
                dropdown.id = 'illuminate-autofill-dropdown';
                const width = Math.max(rect.width, 200);

                dropdown.style.cssText = "position: absolute; top: " + (rect.y + rect.height + window.scrollY + 5) + "px; left: " + (rect.x + window.scrollX) + "px; width: " + width + "px; background: " + "\(bgColor)" + "; border: 1px solid " + "\(borderColor)" + "; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.25); z-index: 1000000; overflow: hidden; font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Helvetica, Arial, sans-serif;";

                accounts.forEach(account => {
                    const item = document.createElement('div');
                    item.style.cssText = `
                        padding: 10px 12px;
                        cursor: pointer;
                        border-bottom: 1px solid \(separatorColor);
                        transition: background 0.2s;
                    `;

                    const username = document.createElement('div');
                    username.textContent = account.username;
                    username.style.cssText = `
                        font-weight: 500;
                        font-size: 13px;
                        color: \(textColor);
                    `;
                    item.appendChild(username);

                    if (account.email) {
                        const email = document.createElement('div');
                        email.textContent = account.email;
                        email.style.cssText = `
                            font-size: 11px;
                            color: \(subColor);
                            margin-top: 2px;
                        `;
                        item.appendChild(email);
                    }

                    item.onmouseover = () => item.style.background = '\(hoverColor)';
                    item.onmouseout = () => item.style.background = '\(bgColor)';
                    item.onclick = (e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        bridge().postMessage({
                            type: 'selectAccount',
                            username: account.username,
                            email: account.email
                        });
                        dropdown.remove();
                    };
                    dropdown.appendChild(item);
                });

                document.body.appendChild(dropdown);
            };

            document.addEventListener('submit', (e) => {
                const form = e.target;
                if (!(form instanceof HTMLFormElement)) return;

                const passwordField = form.querySelector('input[type="password"]');
                if (!passwordField) return;

                const emailField = form.querySelector('input[type="email"], input[name*="email"]');
                const userField = form.querySelector(
                    'input[autocomplete="username"], ' +
                    'input[name*="user"], ' +
                    'input[name*="login"], ' +
                    'input[type="text"], ' +
                    'input[type="tel"], ' +
                    'input:not([type])'
                );

                if (!userField && !emailField) return;
                const username = userField ? userField.value.trim() : '';
                const email = emailField ? emailField.value.trim() : '';

                window.webkit.messageHandlers.passwordBridge.postMessage({
                    type: 'savePassword',
                    url: window.location.href,
                    username: username,
                    email: email,
                    password: passwordField.value
                });
            }, { capture: true });
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }
}
