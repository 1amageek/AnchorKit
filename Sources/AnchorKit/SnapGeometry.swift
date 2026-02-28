import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// Pure geometry helpers for snap-to-anchor positioning.
///
/// All methods are static and side-effect free. They compute anchor
/// positions, nearest-anchor resolution, bounds clamping, overlap
/// detection, and deceleration projection.
public enum SnapGeometry {

    #if canImport(UIKit)
    private static let decelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
    #else
    private static let decelerationRate: CGFloat = 0.998
    #endif

    // MARK: - Deceleration Projection

    /// Distance travelled after decelerating to zero velocity at a constant rate.
    ///
    /// Based on WWDC 2018 "Designing Fluid Interfaces".
    public static func project(initialVelocity: CGFloat) -> CGFloat {
        (initialVelocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    }

    // MARK: - Anchor Positions

    /// Compute the center-point position for a single anchor within canvas bounds.
    ///
    /// When the canvas is smaller than the content on an axis, the position
    /// is centered on that axis.
    public static func anchorPosition(
        _ anchor: SnapAnchor,
        in canvasSize: CGSize,
        contentSize: CGSize,
        insets: SnapInsets
    ) -> CGPoint {
        let (xs, ys) = axisPositions(
            canvasSize: canvasSize,
            contentSize: contentSize,
            insets: insets
        )
        let x: CGFloat
        let y: CGFloat

        // Horizontal
        if anchor.contains(.topLeading) || anchor.contains(.leading) || anchor.contains(.bottomLeading) {
            x = xs.leading
        } else if anchor.contains(.topTrailing) || anchor.contains(.trailing) || anchor.contains(.bottomTrailing) {
            x = xs.trailing
        } else {
            x = xs.center
        }

        // Vertical
        if anchor.contains(.topLeading) || anchor.contains(.top) || anchor.contains(.topTrailing) {
            y = ys.top
        } else if anchor.contains(.bottomLeading) || anchor.contains(.bottom) || anchor.contains(.bottomTrailing) {
            y = ys.bottom
        } else {
            y = ys.center
        }

        return CGPoint(x: x, y: y)
    }

    /// All positions for the enabled anchors.
    ///
    /// Returns an array of `(anchor, position)` pairs for each individual
    /// anchor that is set in the `anchors` option set.
    public static func anchorPositions(
        for anchors: SnapAnchor,
        in canvasSize: CGSize,
        contentSize: CGSize,
        insets: SnapInsets
    ) -> [(anchor: SnapAnchor, position: CGPoint)] {
        anchors.enabledAnchors.map { anchor in
            (anchor, anchorPosition(anchor, in: canvasSize, contentSize: contentSize, insets: insets))
        }
    }

    // MARK: - Nearest Anchor

    /// Find the enabled anchor nearest to a point by Euclidean distance.
    ///
    /// Returns the anchor and its position. If no anchors are enabled,
    /// falls back to `.center`.
    public static func nearestAnchor(
        to point: CGPoint,
        from anchors: SnapAnchor,
        in canvasSize: CGSize,
        contentSize: CGSize,
        insets: SnapInsets
    ) -> (anchor: SnapAnchor, position: CGPoint) {
        let candidates = anchorPositions(
            for: anchors,
            in: canvasSize,
            contentSize: contentSize,
            insets: insets
        )
        guard let nearest = candidates.min(by: {
            distance($0.position, point) < distance($1.position, point)
        }) else {
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            return (.center, center)
        }
        return nearest
    }

    // MARK: - Clamping

    /// Clamp a center point so the content stays within the canvas bounds.
    ///
    /// When the canvas is smaller than the content on an axis,
    /// the point is centered on that axis.
    public static func clamped(
        _ point: CGPoint,
        in canvasSize: CGSize,
        contentSize: CGSize,
        insets: SnapInsets
    ) -> CGPoint {
        let halfW = contentSize.width / 2
        let halfH = contentSize.height / 2
        let minX = halfW + insets.leading
        let maxX = canvasSize.width - halfW - insets.trailing
        let minY = halfH + insets.top
        let maxY = canvasSize.height - halfH - insets.bottom
        return CGPoint(
            x: minX <= maxX ? max(minX, min(maxX, point.x)) : canvasSize.width / 2,
            y: minY <= maxY ? max(minY, min(maxY, point.y)) : canvasSize.height / 2
        )
    }

    // MARK: - Overlap Detection

    /// AABB collision test for two items given their center points and sizes.
    public static func itemsOverlap(
        _ a: CGPoint,
        _ b: CGPoint,
        sizeA: CGSize,
        sizeB: CGSize
    ) -> Bool {
        let halfWidthSum = (sizeA.width + sizeB.width) / 2
        let halfHeightSum = (sizeA.height + sizeB.height) / 2
        return abs(a.x - b.x) < halfWidthSum && abs(a.y - b.y) < halfHeightSum
    }

    // MARK: - Private Helpers

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Axis positions for the 3×3 anchor grid.
    private static func axisPositions(
        canvasSize: CGSize,
        contentSize: CGSize,
        insets: SnapInsets
    ) -> (xs: (leading: CGFloat, center: CGFloat, trailing: CGFloat),
          ys: (top: CGFloat, center: CGFloat, bottom: CGFloat)) {
        let halfW = contentSize.width / 2
        let halfH = contentSize.height / 2

        let minX = halfW + insets.leading
        let maxX = canvasSize.width - halfW - insets.trailing
        let midX = canvasSize.width / 2

        let minY = halfH + insets.top
        let maxY = canvasSize.height - halfH - insets.bottom
        let midY = canvasSize.height / 2

        return (
            xs: (
                leading: minX <= maxX ? minX : midX,
                center: midX,
                trailing: minX <= maxX ? maxX : midX
            ),
            ys: (
                top: minY <= maxY ? minY : midY,
                center: midY,
                bottom: minY <= maxY ? maxY : midY
            )
        )
    }

}
