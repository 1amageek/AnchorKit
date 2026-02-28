/// Defines how items visually spread when multiple items share the same anchor.
///
/// Implement this protocol to create custom stacking patterns.
/// When `count` is 1, return ``StackTransform/identity``.
/// When `count` is greater than 1, all items (including depth 0) may receive
/// non-identity transforms depending on the layout pattern.
///
/// The `anchor` parameter tells the layout which anchor the items are at,
/// enabling direction-aware spreading (e.g., cascade left when at a right-side anchor).
///
/// ```swift
/// struct MyCustomLayout: StackLayout {
///     func transform(at depth: Int, count: Int, anchor: SnapAnchor) -> StackTransform {
///         guard count > 1 else { return .identity }
///         let dir = anchor.inwardDirection
///         // depth 0 = oldest item, count = total items at this anchor
///         // dir.x/dir.y point toward canvas center (-1, 0, or 1)
///         ...
///     }
/// }
/// ```
public protocol StackLayout: Sendable {

    /// Compute the visual transform for an item at a given depth in the stack.
    ///
    /// - Parameters:
    ///   - depth: Position in the stack. 0 is the topmost (most recently
    ///     interacted) item, increasing for items further behind.
    ///   - count: Total number of items sharing the same anchor.
    ///   - anchor: The individual anchor where the items are stacked.
    ///     Use ``SnapAnchor/inwardDirection`` to get the direction toward canvas center.
    /// - Returns: The transform to apply relative to the anchor position.
    func transform(at depth: Int, count: Int, anchor: SnapAnchor) -> StackTransform
}
