import SwiftUI

/// A stack layout that arranges items along an arc.
///
/// Items behind the top item are distributed symmetrically along an
/// arc defined by the radius and spread angle.
///
/// ```
///     ╭─╮
///    ╱   ╲
///   •     •
/// ```
public struct ArchStackLayout: StackLayout {

    public var radius: CGFloat
    public var spread: Angle

    public init(radius: CGFloat = 60, spread: Angle = .degrees(30)) {
        self.radius = radius
        self.spread = spread
    }

    public func transform(at depth: Int, count: Int, anchor: SnapAnchor) -> StackTransform {
        guard count > 1 else { return .identity }
        let dir = anchor.inwardDirection
        let dirX: CGFloat = dir.x != 0 ? dir.x : 1
        let dirY: CGFloat = dir.y != 0 ? dir.y : 1
        let fraction = Double(depth) / Double(count - 1) - 0.5
        let theta = fraction * spread.radians
        return StackTransform(
            offsetX: radius * CGFloat(sin(theta)) * dirX,
            offsetY: radius * (1 - CGFloat(cos(theta))) * dirY,
            rotation: Angle(radians: theta * Double(dirX))
        )
    }
}
