import SwiftUI

/// A stack layout that offsets items diagonally, like stacked papers.
///
/// ```
/// ┌──────┐
/// │┌─────┤
/// ││     │
/// │└─────┤
/// └──────┘
/// ```
public struct CascadeStackLayout: StackLayout {

    public var spacing: CGFloat

    public init(spacing: CGFloat = 16) {
        self.spacing = spacing
    }

    public func transform(at depth: Int, count: Int, anchor: SnapAnchor) -> StackTransform {
        guard depth > 0 else { return .identity }
        let dir = anchor.inwardDirection
        let offset = CGFloat(depth) * spacing
        return StackTransform(
            offsetX: offset * (dir.x != 0 ? dir.x : 1),
            offsetY: offset * (dir.y != 0 ? dir.y : 1)
        )
    }
}
