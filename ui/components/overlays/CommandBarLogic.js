.pragma library

// Shared command-bar search and result shaping. Keep this independent of QML
// objects so the popup stays focused on interaction and presentation.

const schemeRegex = /^[a-z][a-z0-9+.-]*:\/\//i;
const whitespaceRegex = /\s/;
const domainRegex = /^[^.\s]+\.[^\s]+$/;
const localhostRegex = /^localhost(:\d+)?(\/|$)/i;
const schemePrefixRegex = /^([a-z][a-z0-9+.-]*):/i;
const stripSchemeRegex = /^[a-z][a-z0-9+.-]*:\/\/(www\.)?/i;
const wordBoundaryRegex = /[\s\/._\-:]/;

function looksLikeUrl(text) {
    if (schemeRegex.test(text))
        return true;
    return !whitespaceRegex.test(text) && (domainRegex.test(text) || localhostRegex.test(text));
}

function isInternalUrl(url, schemes) {
    if (whitespaceRegex.test(url))
        return false;
    const match = schemePrefixRegex.exec(url);
    return match !== null && schemes.indexOf(match[1].toLowerCase()) !== -1;
}

function stripScheme(url) {
    return url.replace(stripSchemeRegex, "");
}

function matchScore(haystack, query) {
    const value = String(haystack).toLowerCase();
    const index = value.indexOf(query);
    if (index < 0)
        return 0;
    if (index === 0)
        return 3;
    return wordBoundaryRegex.test(value.charAt(index - 1)) ? 2 : 1;
}

function makeRow(kind, key, fields) {
    return Object.assign({
        key: key,
        kind: kind,
        title: "",
        subtitle: "",
        dest: "",
        url: "",
        iconUrl: "",
        icon: "",
        tabIndex: -1,
        actionIndex: -1
    }, fields);
}

function sameRow(a, b) {
    return a.kind === b.kind && a.title === b.title && a.subtitle === b.subtitle
        && a.dest === b.dest && a.url === b.url && a.iconUrl === b.iconUrl
        && a.icon === b.icon && a.tabIndex === b.tabIndex && a.actionIndex === b.actionIndex;
}

function compatible(list, query) {
    return list.filter(item => item.text.toLowerCase().includes(query)
                               || (item.url !== "" && item.url.toLowerCase().includes(query)));
}

function evaluateMath(text) {
    const trimmed = text.trim();
    if (trimmed.length < 3)
        return null;
    // Must contain at least one math operator: +, -, *, /, %, ^
    if (!/[+\-*\/%^]/.test(trimmed))
        return null;
    // Only allow digits, whitespace, parentheses, decimal point, operators
    if (!/^[\d\s+\-*\/%^.(),]+$/.test(trimmed))
        return null;
    // Don't calculate if it looks like a version or date or bare number
    if (/^\d+(\.\d+)?$/.test(trimmed))
        return null;
    try {
        let sanitized = trimmed.replace(/,/g, "").replace(/\^/g, "**");
        // Check syntax without dangerous tokens
        const fn = new Function("return (" + sanitized + ");");
        const val = fn();
        if (typeof val === "number" && !isNaN(val) && isFinite(val)) {
            // format clean
            let str = String(val);
            if (str.includes(".")) {
                const rounded = parseFloat(val.toFixed(8));
                str = String(rounded);
            }
            return { expr: trimmed, result: str };
        }
    } catch (e) {}
    return null;
}

const bangs = {
    "!g": { name: "Google", url: "https://www.google.com/search?q=%s" },
    "!w": { name: "Wikipedia", url: "https://en.wikipedia.org/wiki/Special:Search?search=%s" },
    "!yt": { name: "YouTube", url: "https://www.youtube.com/results?search_query=%s" },
    "!ddg": { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
    "!gh": { name: "GitHub", url: "https://github.com/search?q=%s" },
    "!r": { name: "Reddit", url: "https://www.reddit.com/search/?q=%s" },
    "!a": { name: "Amazon", url: "https://www.amazon.com/s?k=%s" },
    "!m": { name: "Google Maps", url: "https://www.google.com/maps/search/%s" }
};

function parseBang(text) {
    const trimmed = text.trim();
    const parts = trimmed.split(/\s+/);
    if (parts.length === 0)
        return null;
    const first = parts[0].toLowerCase();
    const last = parts[parts.length - 1].toLowerCase();
    let bangKey = "";
    let query = "";
    if (bangs[first]) {
        bangKey = first;
        query = trimmed.slice(parts[0].length).trim();
    } else if (bangs[last]) {
        bangKey = last;
        query = trimmed.slice(0, trimmed.length - parts[parts.length - 1].length).trim();
    }
    if (bangKey) {
        const entry = bangs[bangKey];
        const searchUrl = entry.url.replace("%s", encodeURIComponent(query));
        return {
            name: entry.name,
            query: query,
            url: searchUrl,
            bang: bangKey
        };
    }
    return null;
}

function buildResults(context) {
    const text = context.text.trim();
    if (text === "" || !context.queryActive)
        return [];
    const query = text.toLowerCase();

    // Check for inline calculation
    const calcEnabled = context.calculatorEnabled !== false;
    const calc = calcEnabled ? evaluateMath(text) : null;
    const calcRow = calc ? makeRow("calc", "calc:" + calc.result, {
        title: calc.result,
        subtitle: "= " + calc.expr + " (Calculation)",
        dest: calc.result
    }) : null;

    // Check for search bang (!g, !w, !yt, etc.)
    const bangsEnabled = context.bangsEnabled !== false;

    // If text starts with '!' and has no spaces, show matching/all bangs
    if (bangsEnabled && text.startsWith("!")) {
        const spaceIdx = text.indexOf(" ");
        if (spaceIdx === -1) {
            const typedBang = text.toLowerCase();
            const bangKeys = Object.keys(bangs);
            const matchingKeys = bangKeys.filter(k => k.startsWith(typedBang));
            if (matchingKeys.length > 0) {
                return matchingKeys.map(k => {
                    const b = bangs[k];
                    return makeRow("bang", "bang:" + k, {
                        title: k + "  —  " + b.name,
                        subtitle: "Search " + b.name,
                        dest: k + " "
                    });
                });
            }
        }
    }

    const bang = bangsEnabled ? parseBang(text) : null;
    const goSubtitle = bang
        ? "Search " + bang.name + " (" + bang.bang + ")"
        : (looksLikeUrl(text) ? "Open" : "Search " + context.searchEngineName);
    const goDest = bang ? bang.url : text;

    const go = makeRow("go", "go", {
        title: bang && bang.query ? bang.query : text,
        subtitle: goSubtitle,
        dest: goDest
    });

    const actionPrefix = query.startsWith(">") || query.startsWith(":");
    const searchQuery = actionPrefix ? query.slice(1).trim() : query;

    const actionHits = [];
    for (let i = 0; i < context.quickActions.length; ++i) {
        const score = searchQuery === "" ? 1 : matchScore(context.quickActions[i].label, searchQuery);
        if (score > 0)
            actionHits.push({ score: score, order: i });
    }
    actionHits.sort((a, b) => b.score - a.score || a.order - b.order);
    const maxActions = actionPrefix ? actionHits.length : Math.min(2, actionHits.length);
    const actionRows = actionHits.slice(0, maxActions).map(hit => {
        const action = context.quickActions[hit.order];
        return makeRow("action", "action:" + action.label, {
            title: String(action.label), subtitle: "Action", icon: String(action.icon || ""), actionIndex: hit.order
        });
    });

    if (actionPrefix) {
        return actionRows;
    }

    const tabHits = [];
    const tabUrls = {};
    for (let i = context.tabs.count - 1; i >= 0; --i) {
        if (context.mode === "edit" && i === context.tabs.activeIndex)
            continue;
        const tab = context.tabs.itemAt(i);
        if (!tab)
            continue;
        const url = tab.url.toString();
        if (isInternalUrl(url, context.internalSchemes))
            continue;
        const title = String(tab.title || "");
        const score = Math.max(matchScore(title, query), matchScore(stripScheme(url), query));
        if (score > 0)
            tabHits.push({ score: score, order: tabHits.length, index: i, title: title, url: url, iconUrl: tab.iconUrl.toString() });
    }
    tabHits.sort((a, b) => b.score - a.score || a.order - b.order);
    const tabRows = tabHits.slice(0, 3).map(hit => {
        tabUrls[hit.url] = true;
        return makeRow("tab", "tab:" + hit.index + ":" + hit.url, {
            title: hit.title, subtitle: "Switch to Tab", url: hit.url, iconUrl: hit.iconUrl, tabIndex: hit.index
        });
    });

    const bookmarkRows = [];
    const bookmarkUrls = {};
    if (context.bookmarks && typeof context.bookmarks.count === "number") {
        const bookmarkHits = [];
        for (let i = 0; i < context.bookmarks.count; ++i) {
            const bm = context.bookmarks.itemAt(i);
            if (!bm)
                continue;
            const bUrl = String(bm.url || "");
            if (bUrl === "" || isInternalUrl(bUrl, context.internalSchemes) || tabUrls[bUrl])
                continue;
            const bTitle = String(bm.title || "");
            const score = Math.max(matchScore(bTitle, query), matchScore(stripScheme(bUrl), query));
            if (score > 0) {
                bookmarkHits.push({
                    score: score,
                    order: bookmarkHits.length,
                    title: bTitle,
                    url: bUrl,
                    iconUrl: String(bm.iconUrl || "")
                });
            }
        }
        bookmarkHits.sort((a, b) => b.score - a.score || a.order - b.order);
        for (let i = 0; i < Math.min(3, bookmarkHits.length); ++i) {
            const hit = bookmarkHits[i];
            bookmarkUrls[hit.url] = true;
            bookmarkRows.push(makeRow("bookmark", "bookmark:" + hit.url, {
                title: hit.title, subtitle: hit.url, dest: hit.url, url: hit.url, iconUrl: hit.iconUrl
            }));
        }
    }

    const searchRows = [];
    const seen = {};
    if (context.suggestions) {
        for (const suggestion of context.suggestions) {
            if (suggestion.isBookmark) {
                if (isInternalUrl(suggestion.url, context.internalSchemes) || tabUrls[suggestion.url] || bookmarkUrls[suggestion.url])
                    continue;
                bookmarkUrls[suggestion.url] = true;
                bookmarkRows.push(makeRow("bookmark", "bookmark:" + suggestion.url, {
                    title: suggestion.text, subtitle: suggestion.url, dest: suggestion.url, url: suggestion.url, iconUrl: String(suggestion.iconUrl || "")
                }));
            } else {
                const key = suggestion.text.toLowerCase();
                if (key === query || seen[key] || isInternalUrl(suggestion.text, context.internalSchemes))
                    continue;
                seen[key] = true;
                searchRows.push(makeRow("suggest", "suggest:" + key, { title: suggestion.text, dest: suggestion.text }));
            }
        }
    }

    const topRows = calcRow ? [calcRow, go] : [go];
    const local = actionRows.concat(tabRows, bookmarkRows.slice(0, 3)).slice(0, context.maxRows - topRows.length - 1);
    const suggestions = searchRows.slice(0, Math.max(0, context.maxRows - topRows.length - local.length));
    return topRows.concat(local, suggestions);
}
