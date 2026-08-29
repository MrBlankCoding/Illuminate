//
//  HistoryPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

// Illuminate://history

import SwiftUI

struct HistoryPageView: View {
    @EnvironmentObject private var tabManager: TabManager
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var viewModel: ContentViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var showClearSheet = false
    @State private var clearRange: ClearRange = .allTime
    @State private var hostToDelete: String? = nil
    @State private var searchResults: [HistoryEntry] = []
    @State private var searchTask: Task<Void, Never>?

    private var theme: BrowserTheme {
        BrowserTheme(accent: tabManager.windowThemeColor, colorScheme: colorScheme, windowThemeColor: tabManager.windowThemeColor)
    }

    private var displayedEntries: [HistoryEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? historyManager.recentEntries : searchResults
    }

    private func groupedEntries(for displayedEntries: [HistoryEntry]) -> [(label: String, entries: [HistoryEntry])] {
        let cal = Calendar.current
        let now = Date()

        var today:    [HistoryEntry] = []
        var yesterday:[HistoryEntry] = []
        var week:     [HistoryEntry] = []
        var older:    [HistoryEntry] = []

        for entry in displayedEntries {
            if cal.isDateInToday(entry.lastVisited) {
                today.append(entry)
            } else if cal.isDateInYesterday(entry.lastVisited) {
                yesterday.append(entry)
            } else {
                let days = cal.dateComponents([.day], from: entry.lastVisited, to: now).day ?? 0
                if days <= 7 { week.append(entry) } else { older.append(entry) }
            }
        }

        var groups: [(label: String, entries: [HistoryEntry])] = []
        if !today.isEmpty     { groups.append((label: "Today",            entries: today)) }
        if !yesterday.isEmpty { groups.append((label: "Yesterday",        entries: yesterday)) }
        if !week.isEmpty      { groups.append((label: "Previous 7 Days",  entries: week)) }
        if !older.isEmpty     { groups.append((label: "Older",            entries: older)) }
        return groups
    }

    var body: some View {
        let entries = displayedEntries
        let groups = groupedEntries(for: entries)

        InternalPage(
            icon: "clock.arrow.circlepath",
            title: "History",
            accentColor: tabManager.windowThemeColor
        ) {
            VStack(alignment: .leading, spacing: 20) {
                if !entries.isEmpty {
                    clearDataSection
                }

                searchBar

                if entries.isEmpty {
                    InternalPageEmptyState(
                        icon: searchText.isEmpty ? "clock" : "magnifyingglass",
                        message: searchText.isEmpty
                            ? "Your browsing history will appear here."
                            : "No history matches \"\(searchText)\"."
                    )
                } else {
                    ForEach(groups, id: \.label) { group in
                        sectionView(label: group.label, entries: group.entries)
                    }
                }
            }
        }
        .confirmationDialog("Clear Browsing Data", isPresented: $showClearSheet, titleVisibility: .visible) {
            Button("Clear \(clearRange.label)", role: .destructive) {
                performClear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your browsing history\(clearRange == .allTime ? " and cannot be undone" : "").")
        }
        .onChange(of: searchText) { oldValue, newValue in
            performSearch(query: newValue)
        }
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            let results = await historyManager.search(query: q)
            if !Task.isCancelled {
                await MainActor.run {
                    self.searchResults = results
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13, weight: .medium))
            TextField("Search history", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private func sectionView(label: String, entries: [HistoryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            LazyVStack(spacing: 1) {
                ForEach(entries) { entry in
                    HistoryRowView(entry: entry) { action in
                        handleRowAction(action, entry: entry)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var clearDataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clear Browsing Data")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 14) {
                Picker("Time range", selection: $clearRange) {
                    ForEach(ClearRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Text("Removes your browsing history for the selected time period.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Clear Browsing Data…") {
                        showClearSheet = true
                    }
                    .buttonStyle(InternalPageChipButtonStyle(color: .red))

                    Spacer()
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        }
    }

    private func performClear() {
        switch clearRange {
        case .lastHour:
            historyManager.clearHistory(since: Date().addingTimeInterval(-3600))
        case .today:
            historyManager.clearToday()
        case .lastWeek:
            historyManager.clearHistory(since: Date().addingTimeInterval(-7 * 86400))
        case .allTime:
            historyManager.clearAll()
        }
    }

    private func handleRowAction(_ action: HistoryRowAction, entry: HistoryEntry) {
        switch action {
        case .open:
            guard let url = entry.url else { return }
            viewModel.navigateToAddressBarURL(url.absoluteString)

        case .delete:
            withAnimation(.easeOut(duration: 0.2)) {
                searchResults.removeAll { $0.id == entry.id }
                historyManager.delete(id: entry.id)
            }

        case .deleteAllFromSite:
            if let host = entry.url?.host {
                withAnimation(.easeOut(duration: 0.2)) {
                    searchResults.removeAll { $0.url?.host == host }
                    historyManager.deleteAll(forHost: host)
                }
            }
        }
    }
}

enum HistoryRowAction {
    case open
    case delete
    case deleteAllFromSite
}

enum ClearRange: String, CaseIterable, Identifiable {
    case lastHour = "lastHour"
    case today    = "today"
    case lastWeek = "lastWeek"
    case allTime  = "allTime"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastHour: return "Last Hour"
        case .today:    return "Today"
        case .lastWeek: return "Last Week"
        case .allTime:  return "All Time"
        }
    }
}

private struct HistoryRowView: View {
    let entry: HistoryEntry
    let onAction: (HistoryRowAction) -> Void

    @EnvironmentObject private var tabManager: TabManager
    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            faviconView

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(entry.urlString)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.timeFormatter.string(from: entry.lastVisited))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                if entry.visitCount > 1 {
                    Text("\(entry.visitCount) visits")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }

            if isHovered {
                HStack(spacing: 6) {
                    Button("Open") {
                        onAction(.open)
                    }
                    .buttonStyle(InternalPageChipButtonStyle(color: tabManager.windowThemeColor))

                    Menu {
                        Button("Delete Entry") {
                            onAction(.delete)
                        }
                        if entry.url?.host != nil {
                            Button("Delete All from This Site") {
                                onAction(.deleteAllFromSite)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 22)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .trailing)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.045) : Color.clear)
        .background(.regularMaterial)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
        .onTapGesture(count: 2) {
            onAction(.open)
        }
        .contextMenu {
            Button("Open") { onAction(.open) }
            Divider()
            Button("Delete Entry") { onAction(.delete) }
            if entry.url?.host != nil {
                Button("Delete All from This Site") { onAction(.deleteAllFromSite) }
            }
        }
    }

    @ViewBuilder
    private var faviconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tabManager.windowThemeColor.opacity(0.12))
                .frame(width: 32, height: 32)

            if let faviconURL = entry.faviconURL,
               faviconURL.scheme == "https" || faviconURL.scheme == "http" {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    default:
                        fallbackFaviconIcon
                    }
                }
            } else {
                fallbackFaviconIcon
            }
        }
    }

    private var fallbackFaviconIcon: some View {
        Image(systemName: "globe")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tabManager.windowThemeColor.opacity(0.7))
    }
}
