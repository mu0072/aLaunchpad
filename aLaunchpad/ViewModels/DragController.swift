import SwiftUI

/// Transient state for a drag-to-reorder gesture on the launcher grid.
///
/// Lives separate from `LauncherViewModel` so that every drag-tick update
/// (translation, hover index) doesn't republish the much larger launcher
/// state to every observer.
@MainActor
final class DragController: ObservableObject {
    /// `AppItem.id` of the icon currently being dragged, or nil when idle.
    @Published var draggingID: String?

    /// Target slot in the full custom-order list. The grid splices the dragged
    /// icon into this index to compute the live "preview order" that drives
    /// the push-aside animation.
    @Published var dragHoverIndex: Int?

    /// Current finger position in the grid's named coordinate space (i.e. the
    /// visible page frame). The dragged cell offsets itself by
    /// `dragLocation - slotCenter(dragHoverIndex)` so it always sits under the
    /// finger even as the layout shuffles around it.
    @Published var dragLocation: CGPoint = .zero

    private var pageFlipTimer: Timer?
    /// Direction the auto-flip timer is currently armed for (-1 prev / +1 next).
    private var armedDirection: Int = 0

    /// Delay before holding in an edge zone triggers a page flip. Re-armed
    /// after each flip so holding keeps flipping at the same cadence.
    private let pageFlipDelay: TimeInterval = 0.6

    var isDragging: Bool { draggingID != nil }

    func endDrag() {
        cancelPageFlip()
        draggingID = nil
        dragHoverIndex = nil
        dragLocation = .zero
    }

    /// Schedule a page-flip in `direction` (-1 prev / +1 next) after the hold
    /// delay. Calling again with the same direction while already armed is a
    /// no-op; switching direction (or calling cancelPageFlip) resets the timer.
    ///
    /// The timer is added to the run loop in `.common` mode so it still fires
    /// while the user is mid-drag — `.scheduledTimer(...)` defaults to
    /// `.default` mode, which is paused during mouse event tracking, and the
    /// page would silently never flip.
    func armPageFlip(direction: Int, fire: @escaping (Int) -> Void) {
        guard direction != 0 else { cancelPageFlip(); return }
        if armedDirection == direction, pageFlipTimer != nil { return }
        cancelPageFlip()
        armedDirection = direction
        let timer = Timer(timeInterval: pageFlipDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let dir = self.armedDirection
                self.pageFlipTimer = nil
                self.armedDirection = 0
                if dir != 0 { fire(dir) }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pageFlipTimer = timer
    }

    func cancelPageFlip() {
        pageFlipTimer?.invalidate()
        pageFlipTimer = nil
        armedDirection = 0
    }
}
