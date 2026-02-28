import SwiftUI

/// The visual transform applied to an item based on its depth in a stack.
public struct StackTransform: Sendable, Equatable {

    public var offsetX: CGFloat
    public var offsetY: CGFloat
    public var rotation: Angle
    public var scale: CGFloat

    public init(
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0,
        rotation: Angle = .zero,
        scale: CGFloat = 1.0
    ) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
        self.scale = scale
    }

    public static let identity = StackTransform()
}
