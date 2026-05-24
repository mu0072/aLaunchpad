import Foundation
import SwiftUI

@MainActor
final class LauncherViewModel: ObservableObject {
    /// Sort order options exposed in the toolbar menu.
    enum SortOption: String, CaseIterable, Identifiable {
        case nameAsc
        case nameDesc
        case dateNewest
        case dateOldest

        var id: String { rawValue }

        var label: String {
            switch self {
            case .nameAsc:    return "Name (A → Z)"
            case .nameDesc:   return "Name (Z → A)"
            case .dateNewest: return "Date Added (Newest)"
            case .dateOldest: return "Date Added (Oldest)"
            }
        }
    }

    @Published private(set) var allApps: [AppItem] = []
    @Published var search: String = ""
    @Published var errorMessage: String?
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var archived: Set<String> = []
    @Published private(set) var isShowingArchive: Bool = false
    @Published private(set) var isScanning: Bool = false
    @Published var selectedID: String?
    @Published private(set) var sortOption: SortOption = .nameAsc
    @Published private(set) var currentPage: Int = 0

    /// Classic Launchpad-style fixed grid: 8 across × 4 down per page.
    let columnsPerPage: Int = 8
    let rowsPerPage: Int = 4
    var itemsPerPage: Int { columnsPerPage * rowsPerPage }

    private let favKey = "aLaunchpad.favorites"
    private let archiveKey = "aLaunchpad.archived"
    private let legacyHiddenKey = "aLaunchpad.hidden"
    private let legacyShowHiddenKey = "aLaunchpad.showHidden"
    private let sortKey = "aLaunchpad.sortOption"
    private let defaults = UserDefaults.standard

    init() {
        favorites = Set(defaults.stringArray(forKey: favKey) ?? [])

        // One-shot migration: v1.1 `hidden` becomes v1.2 `archived`. Merge so a
        // user who already played with both keys doesn't lose either side.
        let newArchived = Set(defaults.stringArray(forKey: archiveKey) ?? [])
        let legacyHidden = Set(defaults.stringArray(forKey: legacyHiddenKey) ?? [])
        archived = newArchived.union(legacyHidden)
        if !legacyHidden.isEmpty {
            defaults.set(Array(archived), forKey: archiveKey)
            defaults.removeObject(forKey: legacyHiddenKey)
            defaults.removeObject(forKey: legacyShowHiddenKey)
        }

        if let raw = defaults.string(forKey: sortKey),
           let opt = SortOption(rawValue: raw) {
            sortOption = opt
        }
    }

    // MARK: - Derived state

    private var visibleApps: [AppItem] {
        if isShowingArchive {
            return allApps.filter { archived.contains($0.id) }
        }
        // Main view hides archived apps by default, but a search query brings
        // them back so the user can still launch them — they render dimmed
        // with a corner badge in AppIconView.
        if search.isEmpty {
            return allApps.filter { !archived.contains($0.id) }
        }
        return allApps
    }

    var displayedFavorites: [AppItem] {
        let favs = visibleApps.filter { favorites.contains($0.id) }
        return applySearch(sorted(favs))
    }

    var displayedOthers: [AppItem] {
        let others = visibleApps.filter { !favorites.contains($0.id) }
        return applySearch(sorted(others))
    }

    var displayedCombined: [AppItem] {
        displayedFavorites + displayedOthers
    }

    private func applySearch(_ list: [AppItem]) -> [AppItem] {
        guard !search.isEmpty else { return list }
        return list.filter { $0.searchTokens.matches(search) }
    }

    private func sorted(_ list: [AppItem]) -> [AppItem] {
        switch sortOption {
        case .nameAsc:
            // Sort by the pinyin-folded form so "迅雷" sorts under 'x' alongside
            // latin names, matching the intuitive A-Z reading order.
            // localizedStandardCompare also gives natural numeric ordering
            // (1Password before 10Password before 2Do).
            return list.sorted {
                $0.searchTokens.pinyin.localizedStandardCompare($1.searchTokens.pinyin) == .orderedAscending
            }
        case .nameDesc:
            return list.sorted {
                $0.searchTokens.pinyin.localizedStandardCompare($1.searchTokens.pinyin) == .orderedDescending
            }
        case .dateNewest:
            return list.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
        case .dateOldest:
            return list.sorted { ($0.dateAdded ?? .distantFuture) < ($1.dateAdded ?? .distantFuture) }
        }
    }

    // MARK: - Pagination

    var pageCount: Int {
        let total = displayedCombined.count
        guard total > 0 else { return 1 }
        return Int(ceil(Double(total) / Double(itemsPerPage)))
    }

    func appsOnPage(_ page: Int) -> [AppItem] {
        let combined = displayedCombined
        let start = page * itemsPerPage
        guard start < combined.count else { return [] }
        let end = min(start + itemsPerPage, combined.count)
        return Array(combined[start..<end])
    }

    func goToPage(_ page: Int) {
        let clamped = max(0, min(pageCount - 1, page))
        currentPage = clamped
        // Move selection onto the new page so keyboard nav doesn't feel
        // disconnected from what's visible.
        let pageItems = appsOnPage(clamped)
        if let first = pageItems.first,
           !pageItems.contains(where: { $0.id == selectedID }) {
            selectedID = first.id
        }
    }

    func nextPage() { goToPage(currentPage + 1) }
    func prevPage() { goToPage(currentPage - 1) }

    // MARK: - Mutations

    func toggleFavorite(_ app: AppItem) {
        if favorites.contains(app.id) {
            favorites.remove(app.id)
        } else {
            favorites.insert(app.id)
        }
        defaults.set(Array(favorites), forKey: favKey)
    }

    func isArchived(_ app: AppItem) -> Bool { archived.contains(app.id) }

    func setArchived(_ app: AppItem, _ value: Bool) {
        if value { archived.insert(app.id) } else { archived.remove(app.id) }
        defaults.set(Array(archived), forKey: archiveKey)
        // If the just-toggled app is gone from the visible list (e.g. archived
        // from the main grid, or unarchived from the archive view), the old
        // selection now points at nothing — snap back to the first item so
        // keyboard navigation never hangs.
        if displayedCombined.firstIndex(where: { $0.id == selectedID }) == nil {
            resetSelectionToFirst()
        }
    }

    func toggleArchive(_ app: AppItem) { setArchived(app, !isArchived(app)) }

    func setShowingArchive(_ value: Bool) {
        guard isShowingArchive != value else { return }
        isShowingArchive = value
        search = ""
        resetSelectionToFirst()
    }

    func setSortOption(_ option: SortOption) {
        sortOption = option
        defaults.set(option.rawValue, forKey: sortKey)
        resetSelectionToFirst()
    }

    func clearSearch() { search = "" }

    func resetTransientState() {
        errorMessage = nil
        search = ""
        resetSelectionToFirst()
    }

    // MARK: - Selection / keyboard navigation

    func resetSelectionToFirst() {
        selectedID = displayedCombined.first?.id
        currentPage = 0
    }

    /// Linear (next/prev). Kept for completeness; the grid uses the directional
    /// helpers below.
    func selectNext() { moveSelection(by: 1) }
    func selectPrev() { moveSelection(by: -1) }

    func selectRight() { moveSelection(by: 1) }
    func selectLeft()  { moveSelection(by: -1) }
    func selectDown()  { moveSelection(by: columnsPerPage) }
    func selectUp()    { moveSelection(by: -columnsPerPage) }

    private func moveSelection(by delta: Int) {
        let combined = displayedCombined
        guard !combined.isEmpty else { selectedID = nil; return }
        let currentIdx = combined.firstIndex(where: { $0.id == selectedID }) ?? 0
        let newIdx = max(0, min(combined.count - 1, currentIdx + delta))
        selectedID = combined[newIdx].id
        currentPage = newIdx / itemsPerPage
    }

    // MARK: - Scanning + launching

    func rescan() {
        isScanning = true
        Task {
            let scanned = await AppScanner.scan()
            let previousID = self.selectedID
            self.allApps = scanned
            self.isScanning = false
            // Preserve the user's selection across rescans (e.g. FSEvents-driven
            // ones that fire mid-search). Only fall back to "first item" if the
            // previously-selected app is no longer in the visible list.
            if let prev = previousID,
               let idx = self.displayedCombined.firstIndex(where: { $0.id == prev }) {
                self.currentPage = idx / self.itemsPerPage
            } else {
                self.resetSelectionToFirst()
            }
        }
    }

    func launch(_ item: AppItem, onSuccess: @escaping () -> Void) {
        Task {
            do {
                try await AppLauncher.launch(item)
                self.errorMessage = nil
                onSuccess()
            } catch {
                self.errorMessage = "Failed to launch \(item.name): \(error.localizedDescription)"
            }
        }
    }

    func launchSelected(onSuccess: @escaping () -> Void) {
        let combined = displayedCombined
        let target = combined.first(where: { $0.id == selectedID }) ?? combined.first
        guard let target else { return }
        launch(target, onSuccess: onSuccess)
    }
}
