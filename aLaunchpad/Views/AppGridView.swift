import SwiftUI

/// Classic-Launchpad-style paged grid: fixed columns × rows per page, with a
/// dot indicator row beneath. Favorites still come first (already ordered in
/// `displayedCombined`) but the visual "Favorites / All Applications" split
/// disappears in paged mode — section headers don't align cleanly with page
/// boundaries.
struct AppGridView: View {
    @ObservedObject var viewModel: LauncherViewModel
    var onLaunch: (AppItem) -> Void

    /// Must match the actual rendered cell height in `AppIconView` (icon 88 +
    /// VStack-spacing 8 + label 30 + vertical padding 12 = 138). Used to spread
    /// rows evenly across the area between the search bar and the dot row.
    private let cellHeight: CGFloat = 138
    private let minRowSpacing: CGFloat = 8
    private let maxRowSpacing: CGFloat = 48

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 24, alignment: .top),
            count: viewModel.columnsPerPage
        )
    }

    var body: some View {
        let apps = viewModel.displayedCombined
        let pageCount = viewModel.pageCount

        VStack(spacing: 14) {
            GeometryReader { geo in
                let spacing = rowSpacing(for: geo.size.height)
                HStack(spacing: 0) {
                    ForEach(0..<max(pageCount, 1), id: \.self) { page in
                        pageGrid(apps: viewModel.appsOnPage(page), spacing: spacing)
                            .frame(width: geo.size.width,
                                   height: geo.size.height,
                                   alignment: .top)
                    }
                }
                .frame(width: geo.size.width,
                       height: geo.size.height,
                       alignment: .topLeading)
                .offset(x: -CGFloat(viewModel.currentPage) * geo.size.width)
                .animation(.easeInOut(duration: 0.28), value: viewModel.currentPage)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if apps.isEmpty {
                emptyState
            } else if pageCount > 1 {
                PageIndicator(count: pageCount, current: viewModel.currentPage) { page in
                    viewModel.goToPage(page)
                }
            } else {
                // Reserve the same vertical space so the grid doesn't jump up
                // when there's only one page of results.
                Color.clear.frame(height: 16)
            }
        }
    }

    /// Spread the leftover vertical space evenly across the gaps between rows
    /// so the grid fills from the top of the panel down to the dot indicator.
    private func rowSpacing(for height: CGFloat) -> CGFloat {
        let rows = max(viewModel.rowsPerPage, 1)
        let gaps = max(rows - 1, 1)
        let raw = (height - cellHeight * CGFloat(rows)) / CGFloat(gaps)
        return min(maxRowSpacing, max(minRowSpacing, raw))
    }

    private func pageGrid(apps: [AppItem], spacing: CGFloat) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(apps) { app in
                AppIconView(app: app,
                            isSelected: app.id == viewModel.selectedID,
                            viewModel: viewModel,
                            onLaunch: onLaunch)
                    .id(app.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        // Leave room around the first and last columns so the selection
        // background (which extends a few points past the cell width) isn't
        // chopped by the page-level `.clipped()` modifier.
        .padding(.horizontal, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.4))
            Text(viewModel.search.isEmpty ? "No applications found" : "No matches for \"\(viewModel.search)\"")
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

/// Old-school macOS Launchpad dots. Tap a dot to jump to that page.
struct PageIndicator: View {
    let count: Int
    let current: Int
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.white.opacity(0.95) : Color.white.opacity(0.30))
                    .frame(width: 11, height: 11)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    )
                    .contentShape(Rectangle().inset(by: -8))
                    .onTapGesture { onSelect(i) }
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}
