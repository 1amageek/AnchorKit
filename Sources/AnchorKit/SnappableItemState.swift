import CoreGraphics

/// Tracked state for a single snappable view within a ``SnappingContainer``.
struct SnappableItemState: Identifiable {
    let id: AnyHashable
    var anchor: SnapAnchor
    var position: CGPoint = .zero
    var size: CGSize
    var zIndex: Int = 0
    /// Whether the item has been assigned a valid position.
    /// Items remain invisible until positioned after canvas size is known.
    var isPositioned: Bool = false
}
