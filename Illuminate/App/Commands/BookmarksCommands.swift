//
//  BookmarksCommands.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import KeyboardShortcuts
import SwiftData

struct BookmarksCommands: Commands {
    let modelContainer: ModelContainer

    var body: some Commands {
        CommandMenu("Bookmarks") {
            BookmarksMenuContent()
                .modelContext(modelContainer.mainContext)
        }
    }
}

struct BookmarksMenuContent: View {
    @Query(sort: \Bookmark.title) private var allBookmarks: [Bookmark]
    @FocusedValue(\.activeEnvironment) private var environment
    @Environment(\.modelContext) private var modelContext

    private var bookmarks: [Bookmark] {
        guard environment?.isGuestSession == false else { return [] }
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
                toggleBookmark()
            }
            .disabled(environment?.isGuestSession == true)
            .globalKeyboardShortcut(.bookmarkTab)

            Divider()

            if bookmarks.isEmpty {
                Button("No bookmarks yet") { }
                    .disabled(true)
            } else {
                ForEach(bookmarks) { bookmark in
                    Button(bookmark.title.isEmpty ? bookmark.url : bookmark.title) {
                        guard let url = URL(string: bookmark.url) else { return }
                        if let existingTab = environment?.tabManager.tabs.first(where: { $0.url?.absoluteString == bookmark.url }) {
                            environment?.tabManager.switchTo(existingTab.id)
                        } else {
                            environment?.tabManager.createTab(url: url)
                        }
                    }
                }
            }
        }
    }
    
    private func toggleBookmark() {
        guard let environment, environment.isGuestSession == false else { return }
        environment.tabManager.toggleBookmark(context: modelContext)
    }
}
