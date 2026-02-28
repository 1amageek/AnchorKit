import CoreGraphics
import Observation

/// Manages the layout state for all snappable items within a ``SnappingContainer``.
///
/// Handles item registration, anchor-based positioning, drag-end snap resolution,
/// z-index ordering, and canvas resize repositioning.
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

    /// Register or update a snappable item at a designated anchor.
    ///
    /// Called by ``SnappableModifier`` on appear and when size changes.
    /// The item is positioned at the anchor computed by ``SnapGeometry``.
    func registerItem(id: AnyHashable, size: CGSize, anchor: SnapAnchor) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].size = size
            items[index].anchor = anchor
            if canvasSize.width > 0, canvasSize.height > 0 {
                items[index].position = SnapGeometry.anchorPosition(
                    anchor, in: canvasSize, contentSize: size, insets: insets
                )
                items[index].isPositioned = true
            }
            return
        }
        var item = SnappableItemState(
            id: id, anchor: anchor, size: size, zIndex: allocateZIndex()
        )
        if canvasSize.width > 0, canvasSize.height > 0 {
            item.position = SnapGeometry.anchorPosition(
                anchor, in: canvasSize, contentSize: size, insets: insets
            )
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

    // MARK: - Anchor Update

    /// Update the anchor assignment for an item.
    ///
    /// Called when the user externally changes the anchor binding.
    /// No-op if the anchor has not changed.
    func updateAnchor(for id: AnyHashable, to anchor: SnapAnchor) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].anchor != anchor else { return }
        items[index].anchor = anchor
        if canvasSize.width > 0, canvasSize.height > 0 {
            items[index].position = SnapGeometry.anchorPosition(
                anchor, in: canvasSize, contentSize: items[index].size, insets: insets
            )
            items[index].isPositioned = true
        }
    }

    // MARK: - Canvas Size

    /// Update the canvas size and reposition items as needed.
    ///
    /// When the canvas transitions from zero to a valid size, all
    /// unpositioned items receive positions at their designated anchors.
    /// On subsequent resizes, all items are repositioned at their anchors.
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
    /// Updates the stored anchor and returns both the anchor and position.
    func resolveSnapTarget(
        for id: AnyHashable,
        currentPosition: CGPoint,
        velocity: CGSize
    ) -> (anchor: SnapAnchor, position: CGPoint) {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            let currentAnchor = items.first { $0.id == id }?.anchor ?? .center
            return (currentAnchor, currentPosition)
        }

        let searchPoint = CGPoint(
            x: currentPosition.x + SnapGeometry.project(initialVelocity: velocity.width),
            y: currentPosition.y + SnapGeometry.project(initialVelocity: velocity.height)
        )

        let contentSize = items.first { $0.id == id }?.size ?? .zero
        let result = SnapGeometry.nearestAnchor(
            to: searchPoint,
            from: anchors,
            in: canvasSize,
            contentSize: contentSize,
            insets: insets
        )

        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].anchor = result.anchor
        }

        return result
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
    /// Items sharing the same anchor form a stack. The oldest item
    /// (lowest z-index) is depth 0, and all items receive transforms
    /// computed by the provided ``StackLayout``.
    func stackTransform(for id: AnyHashable, layout: any StackLayout) -> StackTransform {
        guard let item = items.first(where: { $0.id == id }),
              item.isPositioned else {
            return .identity
        }

        let sameAnchor = items
            .filter { $0.isPositioned && $0.anchor == item.anchor }
            .sorted { $0.zIndex < $1.zIndex }

        guard let depth = sameAnchor.firstIndex(where: { $0.id == id }) else {
            return .identity
        }

        return layout.transform(at: depth, count: sameAnchor.count, anchor: item.anchor)
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

    /// Assign positions to items that have not yet been positioned.
    private func positionUnpositionedItems() {
        for i in items.indices where !items[i].isPositioned {
            items[i].position = SnapGeometry.anchorPosition(
                items[i].anchor,
                in: canvasSize,
                contentSize: items[i].size,
                insets: insets
            )
            items[i].isPositioned = true
        }
    }

    /// Reposition all items at their designated anchors after a canvas resize.
    private func snapAllItems() {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        for i in items.indices where items[i].isPositioned {
            items[i].position = SnapGeometry.anchorPosition(
                items[i].anchor,
                in: canvasSize,
                contentSize: items[i].size,
                insets: insets
            )
        }
    }
}
