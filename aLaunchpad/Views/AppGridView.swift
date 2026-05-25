import SwiftUI

/// Classic-Launchpad-style paged grid: fixed columns × rows per page, with a
/// dot indicator row beneath. Favorites still come first (already ordered in
/// `displayedCombined`) but the visual "Favorites / All Applications" split
/// disappears in paged mode — section headers don't align cleanly with page
/// boundaries.
///
/// When `sortOption == .custom`, icons can be dragged to reorder. The dragged
/// icon follows the finger; other icons animate aside to make room (push-aside
/// preview). Holding the finger inside the leftmost or rightmost 10% of the
/// grid for ~0.6 s flips the page so the user can drop across pages. On
/// release, the icon snaps into the hover slot and the new order is persisted.
struct AppGridView: View {
    @ObservedObject var viewModel: LauncherViewModel
    var onLaunch: (AppItem) -> Void

    @StateObject private var dragController = DragController()

    /// Must match the actual rendered cell height in `AppIconView` (icon 88 +
    /// VStack-spacing 8 + label 30 + vertical padding 12 = 138). Used to spread
    /// rows evenly across the area between the search bar and the dot row.
    private let cellHeight: CGFloat = 138
    private let cellSpacing: CGFloat = 24
    private let horizontalPadding: CGFloat = 12
    private let minRowSpacing: CGFloat = 8
    private let maxRowSpacing: CGFloat = 48
    /// Width of the page-flip trigger band at each side, in points. Kept
    /// narrow on purpose: a percentage-of-width zone would overlap with the
    /// leftmost / rightmost column on wide panels and accidentally flip
    /// pages when the user is just trying to place an icon in col 0 or col 7.
    /// 30 pt lives entirely in the gutter between the outermost icon and
    /// the panel edge.
    private let edgeZoneWidth: CGFloat = 30

    private let gridCoordSpace = "alaunchpad.grid"

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: cellSpacing, alignment: .top),
            count: viewModel.columnsPerPage
        )
    }

    var body: some View {
        let base = viewModel.displayedCombined
        let displayed = previewOrder(base: base)
        let itemsPerPage = viewModel.itemsPerPage
        let pageCount = max(1, Int(ceil(Double(displayed.count) / Double(itemsPerPage))))
        let dragEnabled = viewModel.sortOption == .custom
            && viewModel.search.isEmpty
            && !viewModel.isShowingArchive

        VStack(spacing: 14) {
            GeometryReader { geo in
                let spacing = rowSpacing(for: geo.size.height)
                let columnWidth = columnWidth(for: geo.size.width)
                let rowStride = cellHeight + spacing

                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<pageCount, id: \.self) { page in
                            pageGrid(apps: items(on: page, from: displayed),
                                     spacing: spacing,
                                     columnWidth: columnWidth,
                                     rowStride: rowStride,
                                     displayedIDs: displayed.map(\.id),
                                     dragEnabled: dragEnabled,
                                     baseOrder: base,
                                     geoSize: geo.size)
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

                    // Floating ghost of the dragged icon — lives OUTSIDE the
                    // clipped HStack so it can extend freely into the 10%
                    // edge zones without getting cut off, and it always sits
                    // above the grid (no off-screen-page interference).
                    if let draggingID = dragController.draggingID,
                       let app = base.first(where: { $0.id == draggingID }) {
                        AppIconView(
                            app: app,
                            isSelected: false,
                            viewModel: viewModel,
                            onLaunch: { _ in },
                            isBeingDragged: true,
                            dragOffset: .zero,
                            gridCoordinateSpace: nil,
                            onDragChanged: nil,
                            onDragEnded: nil
                        )
                        .position(dragController.dragLocation)
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .coordinateSpace(name: gridCoordSpace)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if displayed.isEmpty {
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

    // MARK: - Layout math

    /// Spread the leftover vertical space evenly across the gaps between rows
    /// so the grid fills from the top of the panel down to the dot indicator.
    private func rowSpacing(for height: CGFloat) -> CGFloat {
        let rows = max(viewModel.rowsPerPage, 1)
        let gaps = max(rows - 1, 1)
        let raw = (height - cellHeight * CGFloat(rows)) / CGFloat(gaps)
        return min(maxRowSpacing, max(minRowSpacing, raw))
    }

    /// Width of one LazyVGrid column. `.flexible` columns split (available -
    /// gaps) evenly across the column count.
    private func columnWidth(for width: CGFloat) -> CGFloat {
        let cols = max(viewModel.columnsPerPage, 1)
        let avail = width - horizontalPadding * 2 - cellSpacing * CGFloat(cols - 1)
        return max(0, avail / CGFloat(cols))
    }

    /// Center of slot N (0-indexed within a single page), in "grid"-named
    /// coordinate space (i.e. the visible page's frame).
    private func slotCenter(slotInPage: Int,
                            columnWidth: CGFloat,
                            rowStride: CGFloat) -> CGPoint {
        let col = slotInPage % viewModel.columnsPerPage
        let row = slotInPage / viewModel.columnsPerPage
        let x = horizontalPadding
            + CGFloat(col) * (columnWidth + cellSpacing)
            + columnWidth / 2
        let y = CGFloat(row) * rowStride + cellHeight / 2
        return CGPoint(x: x, y: y)
    }

    // MARK: - Drag preview order

    /// The list rendered on screen: when a drag is in progress, splice the
    /// dragged item into `dragHoverIndex` so push-aside happens immediately.
    private func previewOrder(base: [AppItem]) -> [AppItem] {
        guard viewModel.sortOption == .custom,
              let draggingID = dragController.draggingID,
              let hoverIndex = dragController.dragHoverIndex,
              let originIdx = base.firstIndex(where: { $0.id == draggingID }) else {
            return base
        }
        var working = base
        let item = working.remove(at: originIdx)
        let clamped = max(0, min(hoverIndex, working.count))
        working.insert(item, at: clamped)
        return working
    }

    private func items(on page: Int, from all: [AppItem]) -> [AppItem] {
        let start = page * viewModel.itemsPerPage
        guard start < all.count else { return [] }
        let end = min(start + viewModel.itemsPerPage, all.count)
        return Array(all[start..<end])
    }

    // MARK: - Page render

    @ViewBuilder
    private func pageGrid(apps: [AppItem],
                          spacing: CGFloat,
                          columnWidth: CGFloat,
                          rowStride: CGFloat,
                          displayedIDs: [String],
                          dragEnabled: Bool,
                          baseOrder: [AppItem],
                          geoSize: CGSize) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { _, app in
                let isDragged = dragController.draggingID == app.id
                AppIconView(
                    app: app,
                    isSelected: app.id == viewModel.selectedID,
                    viewModel: viewModel,
                    onLaunch: onLaunch,
                    isBeingDragged: false,
                    dragOffset: .zero,
                    gridCoordinateSpace: dragEnabled ? gridCoordSpace : nil,
                    onDragChanged: dragEnabled ? { value in
                        handleDragChanged(app: app,
                                          baseOrder: baseOrder,
                                          value: value,
                                          columnWidth: columnWidth,
                                          rowStride: rowStride,
                                          geoSize: geoSize)
                    } : nil,
                    onDragEnded: dragEnabled ? { _ in
                        handleDragEnded()
                    } : nil
                )
                .id(app.id)
                // While being dragged the cell is just a layout placeholder
                // so other icons push aside around it; the visible ghost is
                // drawn separately as an overlay on the grid.
                .opacity(isDragged ? 0 : 1)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78),
                   value: displayedIDs)
        .frame(maxWidth: .infinity, alignment: .top)
        // Leave room around the first and last columns so the selection
        // background (which extends a few points past the cell width) isn't
        // chopped by the page-level `.clipped()` modifier.
        .padding(.horizontal, horizontalPadding)
    }

    // MARK: - Drag handling

    private func handleDragChanged(app: AppItem,
                                   baseOrder: [AppItem],
                                   value: DragGesture.Value,
                                   columnWidth: CGFloat,
                                   rowStride: CGFloat,
                                   geoSize: CGSize) {
        let hover = hoverIndex(forLocation: value.location,
                               columnWidth: columnWidth,
                               rowStride: rowStride,
                               total: baseOrder.count)
        if dragController.draggingID == nil {
            dragController.draggingID = app.id
        }
        dragController.dragLocation = value.location
        dragController.dragHoverIndex = hover

        // Edge zones — arm the auto page-flip timer.
        let pageCount = max(1, Int(ceil(Double(baseOrder.count) / Double(viewModel.itemsPerPage))))
        let leftEdge = edgeZoneWidth
        let rightEdge = geoSize.width - edgeZoneWidth
        if value.location.x < leftEdge, viewModel.currentPage > 0 {
            dragController.armPageFlip(direction: -1) { dir in
                flipPage(by: dir, total: baseOrder.count)
            }
        } else if value.location.x > rightEdge, viewModel.currentPage < pageCount - 1 {
            dragController.armPageFlip(direction: +1) { dir in
                flipPage(by: dir, total: baseOrder.count)
            }
        } else {
            dragController.cancelPageFlip()
        }
    }

    private func handleDragEnded() {
        // Recompute the preview from live state — the captured `displayedIDs`
        // closure parameter is a snapshot from gesture-creation time and
        // doesn't reflect page-flips or hover-index updates that happened
        // mid-drag (cross-page drops were silently committing the original
        // pre-drag order).
        let live = previewOrder(base: viewModel.displayedCombined)
        let finalIDs = live.map(\.id)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            viewModel.setCustomOrder(finalIDs)
            dragController.endDrag()
        }
    }

    /// Translate a finger location (in "grid" coord space, i.e. visible page
    /// frame) into an absolute index in the full customOrder list.
    private func hoverIndex(forLocation loc: CGPoint,
                            columnWidth: CGFloat,
                            rowStride: CGFloat,
                            total: Int) -> Int {
        guard total > 0 else { return 0 }
        let colStride = columnWidth + cellSpacing
        let localX = max(0, loc.x - horizontalPadding)
        let col = max(0, min(viewModel.columnsPerPage - 1, Int(floor(localX / max(colStride, 1)))))
        let row = max(0, min(viewModel.rowsPerPage - 1, Int(floor(loc.y / max(rowStride, 1)))))
        let slotInPage = row * viewModel.columnsPerPage + col
        let raw = viewModel.currentPage * viewModel.itemsPerPage + slotInPage
        return max(0, min(total - 1, raw))
    }

    private func flipPage(by direction: Int, total: Int) {
        let pageCount = max(1, Int(ceil(Double(total) / Double(viewModel.itemsPerPage))))
        let target = viewModel.currentPage + direction
        guard target >= 0, target < pageCount else { return }
        viewModel.goToPage(target)
        // Bump the dragged item onto a slot on the new page so the visible
        // cell follows along instead of getting stranded on the old page.
        if let hover = dragController.dragHoverIndex {
            let bumped = hover + direction * viewModel.itemsPerPage
            dragController.dragHoverIndex = max(0, min(total - 1, bumped))
        }
        // Re-arm: if the finger is still in the edge zone after the flip,
        // the next onChanged tick will arm again. Keep the flag clean here.
        dragController.cancelPageFlip()
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
