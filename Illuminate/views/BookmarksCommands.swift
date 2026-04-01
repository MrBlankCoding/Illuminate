//
//  BookmarksCommands.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import SwiftData

struct BookmarksCommands: Commands {
    let shortcutHandler: KeyboardShortcutHandler
    let modelContainer: ModelContainer

    var body: some Commands {
        CommandMenu("Bookmarks") {
            BookmarksMenuContent(shortcutHandler: shortcutHandler)
                .modelContext(modelContainer.mainContext)
        }
    }
}

struct BookmarksMenuContent: View {
    @Query(sort: \Bookmark.title) private var allBookmarks: [Bookmark]
    @FocusedValue(\.activeEnvironment) private var environment
    @Environment(\.modelContext) private var modelContext
    let shortcutHandler: KeyboardShortcutHandler

    private var bookmarks: [Bookmark] {
        guard let profileID = environment?.profile.id else { return [] }
        return allBookmarks.filter { $0.profileID == profileID }
    }

    private var isCurrentTabBookmarked: Bool {
        guard let currentURL = environment?.tabManager.activeTab?.url?.absoluteString else { return false }
        return bookmarks.contains { $0.url == currentURL }
    }

    var body: some View {
        VStack {
            Button(isCurrentTabBookmarked ? "Remove Bookmark" : "Bookmark Current Tab") {
                if isCurrentTabBookmarked {
                    removeBookmark()
                } else {
                    shortcutHandler.bookmarkTab()
                }
            }
            .keyboardShortcut("b", modifiers: .command)

            Divider()

            if bookmarks.isEmpty {
                Button("No bookmarks yet") { }
                    .disabled(true)
            } else {
                ForEach(bookmarks) { bookmark in
                    Button(bookmark.title.isEmpty ? bookmark.url : bookmark.title) {
                        if let url = URL(string: bookmark.url) {
                            environment?.tabManager.createTab(url: url)
                        }
                    }
                }
            }
        }
    }
    
    private func removeBookmark() {
        guard let currentURL = environment?.tabManager.activeTab?.url?.absoluteString else { return }
        if let bookmarkToRemove = bookmarks.first(where: { $0.url == currentURL }) {
            modelContext.delete(bookmarkToRemove)
        }
    }
}
