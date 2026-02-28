import CoreGraphics
import Observation

/// Manages the layout state for all snappable items within a ``SnappingContainer``.
///
/// Handles item registration, initial positioning, drag-end snap resolution,
/// z-index ordering, and canvas resize re-snapping.
@MainActor
@Observable
final class SnappingContainerModel {

    let anchors: SnapAnchor
    let insets: SnapInsets

    private(set) var items: [SnappableItemState] = []
    private(set) var canvasSize: CGSize = .zero
    private var nextZIndex: Int = 0

    init(anchors: SnapAnchor, insets: SnapInsets) {
        self.anchors = anchors
        self.insets = insets
    }

    // MARK: - Item Registration

    /// Register or update a snappable item.
    ///
    /// Called by ``SnappableModifier`` on appear and when size changes.
    /// If the item is new and the canvas has a valid size, it is
    /// immediately assigned an initial position.
    func registerItem(id: AnyHashable, size: CGSize) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            let wasZeroSize = items[index].size.width <= 0 || items[index].size.height <= 0
            items[index].size = size
            // Reposition when transitioning from zero to a valid size
            if wasZeroSize, size.width > 0, size.height > 0,
               canvasSize.width > 0, canvasSize.height > 0 {
                let existing = items.enumerated()
                    .filter { $0.offset != index && $0.element.isPositioned }
                    .map { (position: $0.element.position, size: $0.element.size) }
                items[index].position = SnapGeometry.initialPosition(
                    from: anchors,
                    in: canvasSize,
                    contentSize: size,
                    insets: insets,
                    avoiding: existing
                )
                items[index].isPositioned = true
            }
            return
        }
        var item = SnappableItemState(id: id, size: size, zIndex: allocateZIndex())
        if canvasSize.width > 0, canvasSize.height > 0 {
            item.position = nextAvailablePosition(for: size)
            item.isPositioned = true
        }
        items.append(item)
    }

    /// Remove a snappable item.
    ///
    /// Called by ``SnappableModifier`` on disappear.
    func unregisterItem(id: AnyHashable) {
        items.removeAll { $0.id == id }
    }

    // MARK: - Canvas Size

    /// Update the canvas size and reposition items as needed.
    ///
    /// When the canvas transitions from zero to a valid size, all
    /// unpositioned items receive initial positions. On subsequent
    /// resizes, all items are re-snapped to avoid overlap.
    func updateCanvasSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let wasZero = canvasSize.width <= 0 || canvasSize.height <= 0
        let sizeChanged = canvasSize != size
        canvasSize = size
        guard sizeChanged else { return }
        if wasZero {
            positionUnpositionedItems()
        } else {
            snapAllItems()
        }
    }

    // MARK: - Snap Resolution

    /// Resolve the snap target after a drag ends.
    ///
    /// Projects the drag velocity using deceleration (WWDC 2018 Designing
    /// Fluid Interfaces) to estimate where the item would land, then snaps
    /// to the anchor nearest to that projected point.
    func resolveSnapTarget(
        for id: AnyHashable,
        currentPosition: CGPoint,
        velocity: CGSize
    ) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return currentPosition }

        let searchPoint = CGPoint(
            x: currentPosition.x + SnapGeometry.project(initialVelocity: velocity.width),
            y: currentPosition.y + SnapGeometry.project(initialVelocity: velocity.height)
        )

        let contentSize = items.first { $0.id == id }?.size ?? .zero
        return SnapGeometry.nearestAnchor(
            to: searchPoint,
            from: anchors,
            in: canvasSize,
            contentSize: contentSize,
            insets: insets
        ).position
    }

    // MARK: - Position Access

    /// Set the position for a specific item.
    func setPosition(for id: AnyHashable, to point: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].position = point
        items[index].isPositioned = true
    }

    /// Get the current position for an item.
    func position(for id: AnyHashable) -> CGPoint {
        items.first { $0.id == id }?.position ?? .zero
    }

    /// Get the z-index for an item.
    func zIndex(for id: AnyHashable) -> Int {
        items.first { $0.id == id }?.zIndex ?? 0
    }

    /// Whether the item has been assigned a valid position.
    func isPositioned(id: AnyHashable) -> Bool {
        items.first { $0.id == id }?.isPositioned ?? false
    }

    // MARK: - Stack Transform

    /// Compute the visual transform for an item based on its depth in the stack.
    ///
    /// Items sharing the same nearest anchor form a stack. The oldest item
    /// (lowest z-index) is depth 0, and all items receive transforms
    /// computed by the provided ``StackLayout``.
    func stackTransform(for id: AnyHashable, layout: any StackLayout) -> StackTransform {
        guard let item = items.first(where: { $0.id == id }),
              item.isPositioned,
              canvasSize.width > 0, canvasSize.height > 0 else {
            return .identity
        }

        let (itemAnchor, _) = SnapGeometry.nearestAnchor(
            to: item.position,
            from: anchors,
            in: canvasSize,
            contentSize: item.size,
            insets: insets
        )

        let sameAnchor = items
            .filter { other in
                guard other.isPositioned else { return false }
                let (otherAnchor, _) = SnapGeometry.nearestAnchor(
                    to: other.position,
                    from: anchors,
                    in: canvasSize,
                    contentSize: other.size,
                    insets: insets
                )
                return otherAnchor == itemAnchor
            }
            .sorted { $0.zIndex < $1.zIndex }

        guard let depth = sameAnchor.firstIndex(where: { $0.id == id }) else {
            return .identity
        }

        return layout.transform(at: depth, count: sameAnchor.count, anchor: itemAnchor)
    }

    // MARK: - Z-Index

    /// Mark this item as the topmost (most recently interacted).
    func bringToFront(id: AnyHashable) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].zIndex = allocateZIndex()
    }

    // MARK: - Private

    private func allocateZIndex() -> Int {
        nextZIndex += 1
        return nextZIndex
    }

    private func nextAvailablePosition(for contentSize: CGSize) -> CGPoint {
        let existing = items.filter(\.isPositioned).map { (position: $0.position, size: $0.size) }
        return SnapGeometry.initialPosition(
            from: anchors,
            in: canvasSize,
            contentSize: contentSize,
            insets: insets,
            avoiding: existing
        )
    }

    /// Assign positions to items that have not yet been positioned.
    private func positionUnpositionedItems() {
        for i in items.indices where !items[i].isPositioned {
            let existing = items[..<i]
                .filter(\.isPositioned)
                .map { (position: $0.position, size: $0.size) }
            items[i].position = SnapGeometry.initialPosition(
                from: anchors,
                in: canvasSize,
                contentSize: items[i].size,
                insets: insets,
                avoiding: existing
            )
            items[i].isPositioned = true
        }
    }

    /// Re-snap all items to their nearest anchor after a canvas resize.
    ///
    /// Each item independently snaps to the anchor closest to its current
    /// position. Items sharing the same anchor are visually separated by the
    /// ``StackLayout``.
    private func snapAllItems() {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        for i in items.indices where items[i].isPositioned {
            let (_, position) = SnapGeometry.nearestAnchor(
                to: items[i].position,
                from: anchors,
                in: canvasSize,
                contentSize: items[i].size,
                insets: insets
            )
            items[i].position = position
        }
    }
}
