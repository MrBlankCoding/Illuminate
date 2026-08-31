//
//  DownloadsPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI

struct DownloadsPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(ProfileEnvironment.self) private var environment: ProfileEnvironment
    private var downloadManager = DownloadManager.shared

    var body: some View {
        DownloadsHistoryList(
            store: environment.downloadHistoryStore,
            accentColor: tabManager.windowThemeColor
        )
    }
}

struct DownloadsHistoryList: View {
    var store: DownloadHistoryStore
    let accentColor: Color
    var downloadManager = DownloadManager.shared

    @State private var showClearAllConfirmation = false

    private var items: [DownloadHistoryItem] {
        var liveTasksByID: [UUID: DownloadTask] = [:]
        for task in downloadManager.downloads {
            liveTasksByID[task.id] = task
        }

        var result: [DownloadHistoryItem] = []
        for record in store.records {
            let liveTask = liveTasksByID.removeValue(forKey: record.id)
            result.append(DownloadHistoryItem(record: record, liveTask: liveTask))
        }

        let sessionOnlyTasks = liveTasksByID.values.sorted { $0.createdAt > $1.createdAt }
        result.append(contentsOf: sessionOnlyTasks.map { DownloadHistoryItem(record: nil, liveTask: $0) })

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        InternalPage(
            icon: "arrow.down.circle.fill",
            title: "Downloads",
            accentColor: accentColor
        ) {
            let allItems = items
            if allItems.isEmpty {
                InternalPageEmptyState(
                    icon: "arrow.down.circle",
                    message: "Files you download will appear here."
                )
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("\(allItems.count) item\(allItems.count == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Clear All History") {
                            showClearAllConfirmation = true
                        }
                        .buttonStyle(InternalPageChipButtonStyle(color: .red))
                    }

                    VStack(spacing: 6) {
                        ForEach(allItems) { item in
                            DownloadEntryRow(
                                item: item,
                                store: store,
                                accentColor: accentColor,
                                style: .page
                            )
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear all download history?",
            isPresented: $showClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes downloads from your history. Files on disk are kept.")
        }
    }

    private func clearAll() {
        store.clearAll()
        downloadManager.clearFinishedDownloads()
        HapticFeedback.destructiveAction()
    }
}
