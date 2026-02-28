import CoreGraphics

/// Defines the inset distances from each edge of the container
/// within which anchor positions are computed.
public struct SnapInsets: Sendable, Equatable {

    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    /// Create insets with individual edge values.
    public init(
        top: CGFloat = 16,
        leading: CGFloat = 16,
        bottom: CGFloat = 16,
        trailing: CGFloat = 16
    ) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    /// Create uniform insets on all edges.
    public init(all: CGFloat) {
        self.top = all
        self.leading = all
        self.bottom = all
        self.trailing = all
    }
}
