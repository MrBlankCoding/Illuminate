//
//  FindViewModel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/12/26.
//

import SwiftUI
import WebKit
import Combine
import Observation

@MainActor
@Observable
final class FindViewModel {

    var searchText: String = "" {
        didSet {
            searchSubject.send(searchText)
        }
    }
    var isPresented: Bool = false {
        didSet {
            if !isPresented {
                clearHighlights()
                searchText = ""
                totalMatches = 0
                currentMatchIndex = 0
            }
        }
    }
    private(set) var currentMatchIndex: Int = 0
    private(set) var totalMatches: Int = 0

    #if DEBUG
    var matchFound: Bool {
        get { totalMatches > 0 }
        set { totalMatches = newValue ? 1 : 0 }
    }
    #else
    var matchFound: Bool { totalMatches > 0 }
    #endif
    var accentColor: Color = .accentColor

    @ObservationIgnored private weak var webView: WKWebView?
    @ObservationIgnored private var didInjectScript = false
    @ObservationIgnored private let searchSubject = PassthroughSubject<String, Never>()
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init() {
        searchSubject
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.runSearch(text, resetIndex: true)
            }
            .store(in: &cancellables)
    }

    func attach(to webView: WKWebView) {
        self.webView = webView
        self.didInjectScript = false
        if !searchText.isEmpty {
            runSearch(searchText, resetIndex: true)
        }
    }

    func setWebView(_ webView: WKWebView?) {
        self.webView = webView
        if webView == nil {
            clearHighlights()
        }
    }

    func findNext() {
        guard totalMatches > 0 else {
            runSearch(searchText, resetIndex: true)
            return
        }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
        highlightCurrent()
    }

    func findPrevious() {
        guard totalMatches > 0 else {
            runSearch(searchText, resetIndex: true)
            return
        }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
        highlightCurrent()
    }

    func dismiss() {
        isPresented = false
        clearHighlights()
        searchText = ""
        totalMatches = 0
        currentMatchIndex = 0
    }


    private func runSearch(_ query: String, resetIndex: Bool) {
        guard let webView else { return }
        if resetIndex { currentMatchIndex = 0 }

        guard !query.isEmpty else {
            clearHighlights()
            totalMatches = 0
            currentMatchIndex = 0
            return
        }

        injectScriptIfNeeded(into: webView) { [weak self] in
            self?.runHighlight(query: query, on: webView)
        }
    }

    private func highlightCurrent() {
        guard let webView, !searchText.isEmpty else { return }
        runHighlight(query: searchText, on: webView)
    }

    private func runHighlight(query: String, on webView: WKWebView) {
        let queryJSON = encoded(query)
        let matchHex = accentColor.opacity(0.32).hexString()
        let currentHex = accentColor.opacity(0.85).hexString()

        let js = "window.__illuminateFind(\(queryJSON), \"#\(currentHex)\", \"#\(matchHex)\", \(currentMatchIndex));"

        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self else { return }
            if let error {
                AppLog.info("Find in page JS error: \(error.localizedDescription)")
                return
            }
            guard let dict = result as? [String: Any],
                  let total = dict["total"] as? Int,
                  let current = dict["current"] as? Int else { return }
            self.totalMatches = total
            self.currentMatchIndex = total > 0 ? current : 0
        }
    }

    private func clearHighlights() {
        guard let webView, didInjectScript else { return }
        webView.evaluateJavaScript("window.__illuminateFind('', '#000000', '#000000', 0);", completionHandler: nil)
    }

    private func injectScriptIfNeeded(into webView: WKWebView, completion: @escaping () -> Void) {
        guard !didInjectScript else {
            completion()
            return
        }
        webView.evaluateJavaScript(Self.findScriptSource) { [weak self] _, error in
            if let error {
                AppLog.info("Failed to inject find script: \(error.localizedDescription)")
            }
            self?.didInjectScript = true
            completion()
        }
    }

    private func encoded(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string], options: []),
              let arrayLiteral = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(arrayLiteral.dropFirst().dropLast())
    }

    private static let findScriptSource = """
    (function() {
      // Stale-result detection: a MutationObserver marks the result set as
      // stale when the DOM changes, but nothing is rescanned until the user
      // actually interacts again. Rebuilds are only done when (a) the query
      // changed or (b) results are stale; otherwise find-next/previous just
      // restyles and scrolls — no DOM walk.
      function ensureObserver() {
        if (window.__illuminateFindObserver) return;
        var observer = new MutationObserver(function() {
          // Ignore mutations caused by our own mark rebuilds.
          if (Date.now() - (window.__illuminateFindRebuiltAt || 0) < 150) return;
          window.__illuminateFindStale = true;
        });
        observer.observe(document.documentElement, {
          childList: true,
          subtree: true,
          characterData: true
        });
        window.__illuminateFindObserver = observer;
      }

      function stripMarks(marks) {
        marks.forEach(function(el) {
          var parent = el.parentNode;
          if (!parent) return;
          parent.replaceChild(document.createTextNode(el.textContent), el);
          parent.normalize();
        });
      }

      function illuminateFind(query, activeColor, matchColor, currentIndex) {
        ensureObserver();
        var existing = document.querySelectorAll('mark[data-illuminate-find]');
        var isSameQuery = !!query && window.__illuminateLastQuery === query && existing.length > 0;
        var needsRebuild = !isSameQuery || !!window.__illuminateFindStale;

        if (!query) {
          stripMarks(existing);
          if (window.__illuminateFindObserver) {
            window.__illuminateFindObserver.disconnect();
            window.__illuminateFindObserver = null;
          }
          window.__illuminateLastQuery = '';
          window.__illuminateFindStale = false;
          return { total: 0, current: 0 };
        }

        if (needsRebuild) {
          stripMarks(existing);

          var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
            acceptNode: function(node) {
              if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
              var tag = node.parentNode ? node.parentNode.nodeName : '';
              if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'TEXTAREA') {
                return NodeFilter.FILTER_REJECT;
              }
              return NodeFilter.FILTER_ACCEPT;
            }
          });

          var lowerQuery = query.toLowerCase();
          var nodes = [];
          var node;
          while (node = walker.nextNode()) { nodes.push(node); }

          nodes.forEach(function(textNode) {
            var text = textNode.nodeValue;
            var lowerText = text.toLowerCase();
            var pos, idx = 0, lastEnd = 0, found = false;
            var frag = document.createDocumentFragment();
            while ((pos = lowerText.indexOf(lowerQuery, idx)) !== -1) {
              found = true;
              frag.appendChild(document.createTextNode(text.slice(lastEnd, pos)));
              var mark = document.createElement('mark');
              mark.setAttribute('data-illuminate-find', '1');
              mark.style.backgroundColor = matchColor;
              mark.style.color = 'inherit';
              mark.style.borderRadius = '2px';
              mark.textContent = text.slice(pos, pos + query.length);
              frag.appendChild(mark);
              lastEnd = pos + query.length;
              idx = lastEnd;
            }
            if (found) {
              frag.appendChild(document.createTextNode(text.slice(lastEnd)));
              textNode.parentNode.replaceChild(frag, textNode);
            }
          });

          window.__illuminateFindRebuiltAt = Date.now();
        }

        window.__illuminateLastQuery = query;
        window.__illuminateFindStale = false;

        var marks = document.querySelectorAll('mark[data-illuminate-find]');
        var total = marks.length;
        var current = 0;
        if (total > 0) {
          current = ((currentIndex % total) + total) % total;
          marks.forEach(function(m, i) {
            m.style.backgroundColor = (i === current) ? activeColor : matchColor;
          });
          marks[current].scrollIntoView({ block: 'center', behavior: 'smooth' });
        }

        return { total: total, current: current };
      }
      window.__illuminateFind = illuminateFind;
    })();
    """
}
