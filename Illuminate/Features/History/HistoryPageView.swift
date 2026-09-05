//
//  HistoryPageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

// Illuminate://history

import SwiftUI

struct HistoryPageView: View {
    @Environment(TabManager.self) private var tabManager: TabManager
    @Environment(HistoryManager.self) private var historyManager: HistoryManager
    @Environment(ContentViewModel.self) private var viewModel: ContentViewModel
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
            VStack(alignment: .leading, spacing: MacDesign.Spacing.section) {
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
        HStack(spacing: MacDesign.Spacing.medium) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.webCaption.weight(.medium))
            TextField("Search history", text: $searchText)
                .textFieldStyle(.plain)
                .font(.webCaption)
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
        .padding(.horizontal, MacDesign.Spacing.toolbarPadding)
        .padding(.vertical, MacDesign.Spacing.medium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MacDesign.Radius.control, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin)
        }
    }

    @ViewBuilder
    private func sectionView(label: String, entries: [HistoryEntry]) -> some View {
        VStack(alignment: .leading, spacing: MacDesign.Spacing.tight) {
            Text(label)
                .font(.webSmallRegular.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, MacDesign.Spacing.small)

            LazyVStack(spacing: MacDesign.Spacing.hairline) {
                ForEach(entries) { entry in
                    HistoryRowView(entry: entry) { action in
                        handleRowAction(action, entry: entry)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
        }
    }

    private var clearDataSection: some View {
        VStack(alignment: .leading, spacing: MacDesign.Spacing.tight) {
            Text("Clear Browsing Data")
                .font(.webSmallRegular.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, MacDesign.Spacing.small)

            VStack(alignment: .leading, spacing: MacDesign.Spacing.toolbarPadding) {
                Picker("Time range", selection: $clearRange) {
                    ForEach(ClearRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Text("Removes your browsing history for the selected time period.")
                    .font(.webMicro)
                    .foregroundStyle(.secondary)

                HStack(spacing: MacDesign.Spacing.medium) {
                    Button("Clear Browsing Data…") {
                        showClearSheet = true
                    }
                    .buttonStyle(InternalPageChipButtonStyle(color: .red))

                    Spacer()
                }
            }
            .padding(MacDesign.Spacing.toolbarPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MacDesign.Radius.medium, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: MacDesign.Spacing.hairlineThin)
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
        HapticFeedback.destructiveAction()
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

    @Environment(TabManager.self) private var tabManager: TabManager
    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: MacDesign.Spacing.regular) {
            faviconView

            VStack(alignment: .leading, spacing: MacDesign.Spacing.micro) {
                Text(entry.displayTitle)
                    .font(.webCaption.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(entry.urlString)
                    .font(.webSmallRegular)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: MacDesign.Spacing.micro) {
                Text(Self.timeFormatter.string(from: entry.lastVisited))
                    .font(.webSmallRegular)
                    .foregroundStyle(.tertiary)

                if entry.visitCount > 1 {
                    Text("\(entry.visitCount) visits")
                        .font(.webSmall)
                        .foregroundStyle(.quaternary)
                }
            }

            if isHovered {
                HStack(spacing: MacDesign.Spacing.tight) {
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
                            .font(.webSmallRegular.weight(.semibold))
                            .frame(width: 26, height: 22)
                            .background(Color.suggestionRowHover, in: Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .trailing)))
            }
        }
        .padding(.horizontal, MacDesign.Spacing.toolbarPadding)
        .padding(.vertical, MacDesign.Spacing.medium)
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
            RoundedRectangle(cornerRadius: MacDesign.Radius.small, style: .continuous)
                .fill(tabManager.windowThemeColor.opacity(0.12))
                .frame(width: MacDesign.Size.largeIconButton, height: MacDesign.Size.largeIconButton)

            if let faviconURL = entry.faviconURL,
               faviconURL.scheme == "https" || faviconURL.scheme == "http" || faviconURL.scheme == "data" {
                NukeFaviconView(url: faviconURL, size: 18)
                    .frame(width: 18, height: 18)
            } else {
                fallbackFaviconIcon
            }
        }
    }

    private var fallbackFaviconIcon: some View {
        Image(systemName: "globe")
            .font(.webBody.weight(.medium))
            .foregroundStyle(tabManager.windowThemeColor.opacity(0.7))
    }
}
