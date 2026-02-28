import SwiftUI

/// A stack layout that rotates items like a hand of cards.
///
/// Each deeper item rotates by the specified angle increment.
/// Positive angles fan clockwise, negative angles fan counter-clockwise.
///
/// ```
///    ╱│╲
///   ╱ │ ╲
///    ─┴─
/// ```
public struct FanStackLayout: StackLayout {

    public var angle: Angle

    public init(angle: Angle = .degrees(5)) {
        self.angle = angle
    }

    public func transform(at depth: Int, count: Int, anchor: SnapAnchor) -> StackTransform {
        guard count > 1 else { return .identity }
        let dir = anchor.inwardDirection
        let sign = dir.x != 0 ? Double(dir.x) : 1.0
        let center = Double(count - 1) / 2.0
        let rotation = Angle.degrees((Double(depth) - center) * angle.degrees * sign)
        return StackTransform(rotation: rotation)
    }
}
