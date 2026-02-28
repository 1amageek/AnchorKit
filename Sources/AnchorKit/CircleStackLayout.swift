import SwiftUI

/// A stack layout that arranges items in a circle around the anchor.
///
/// Items behind the top item are evenly distributed along a circle
/// of the specified radius.
public struct CircleStackLayout: StackLayout {

    public var radius: CGFloat

    public init(radius: CGFloat = 40) {
        self.radius = radius
    }

    public func transform(at depth: Int, count: Int, anchor: SnapAnchor) -> StackTransform {
        guard count > 1 else { return .identity }
        let dir = anchor.inwardDirection
        let baseAngle: Double
        if dir.x == 0, dir.y == 0 {
            baseAngle = 0
        } else {
            baseAngle = atan2(Double(dir.y), Double(dir.x != 0 ? dir.x : 1))
        }
        let theta = baseAngle + 2 * .pi * Double(depth) / Double(count)
        return StackTransform(
            offsetX: radius * CGFloat(cos(theta)),
            offsetY: radius * CGFloat(sin(theta))
        )
    }
}
