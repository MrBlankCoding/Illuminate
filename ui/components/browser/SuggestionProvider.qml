import QtQuick
import illuminate.ui

Item {
    id: root

    readonly property ListModel model: suggestionModel
    readonly property int count: suggestionModel.count
    property string query: ""

    ListModel {
        id: suggestionModel
    }

    property var localMatches: []
    property var cache: ({})

    function update(text) {
        root.query = text.trim();
        if (root.query === "") {
            root.clear();
            return;
        }

        const q = root.query.toLowerCase();
        const local = [];
        for (let i = 0; i < Bookmarks.count && local.length < 3; i++) {
            const bm = Bookmarks.itemAt(i);
            if (bm.title.toLowerCase().includes(q) || bm.url.toLowerCase().includes(q))
                local.push({ text: bm.title, url: bm.url, isBookmark: true });
        }
        root.localMatches = local;

        const cached = root.cache[q];
        if (cached && cached.length > 0) {
            debounce.stop();
            remoteRequest.cancel();
            const merged = local.slice();
            for (let i = 0; i < cached.length && merged.length < 8; i++) {
                const s = cached[i];
                if (!merged.some(item => item.text.toLowerCase() === s.text.toLowerCase()))
                    merged.push(s);
            }
            root.apply(merged);
            return;
        }

        root.apply(local);
        debounce.restart();
    }

    function clear() {
        debounce.stop();
        remoteRequest.cancel();
        root.query = "";
        root.localMatches = [];
        suggestionModel.clear();
    }

    // what to navigate to for row i: a bookmark URL or the completion text
    function inputAt(i) {
        if (i < 0 || i >= suggestionModel.count)
            return "";
        const item = suggestionModel.get(i);
        return (item.isBookmark ? item.url : item.text) || item.text;
    }

    function apply(list) {
        suggestionModel.clear();
        for (let i = 0; i < list.length; i++)
            suggestionModel.append(list[i]);
    }

    Timer {
        id: debounce
        interval: 60
        onTriggered: root.fetch(root.query)
    }

    SearchSuggestionRequest {
        id: remoteRequest
        onSuggestionsReady: function (query, values) {
            const qKey = query.trim().toLowerCase();
            const suggestionsList = [];
            for (let i = 0; i < values.length && suggestionsList.length < 8; i++) {
                const suggestion = values[i];
                suggestionsList.push({ text: suggestion, url: "", isBookmark: false });
            }
            root.cache[qKey] = suggestionsList;

            if (query !== root.query)
                return;
            const merged = root.localMatches.slice();
            for (let i = 0; i < suggestionsList.length && merged.length < 8; i++) {
                const s = suggestionsList[i];
                if (!merged.some(item => item.text.toLowerCase() === s.text.toLowerCase()))
                    merged.push(s);
            }
            root.apply(merged);
        }
    }

    function fetch(query) {
        if (query === "") {
            suggestionModel.clear();
            return;
        }
        remoteRequest.cancel();
        if (!Prefs.searchSuggestionsEnabled)
            return;
        remoteRequest.fetch(query);
    }
}
