import Foundation

/// Defines the set of anchor positions where snappable views can rest.
///
/// Anchors form a 3×3 grid within the container bounds:
/// ```
/// topLeading     top      topTrailing
/// leading       center      trailing
/// bottomLeading  bottom  bottomTrailing
/// ```
///
/// Use as an `OptionSet` to enable any combination:
/// ```swift
/// let anchors: SnapAnchor = [.corners, .center]
/// ```
public struct SnapAnchor: OptionSet, Sendable, Hashable, Codable {

    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    // MARK: - Individual Anchors

    public static let topLeading     = SnapAnchor(rawValue: 1 << 0)
    public static let top            = SnapAnchor(rawValue: 1 << 1)
    public static let topTrailing    = SnapAnchor(rawValue: 1 << 2)

    public static let leading        = SnapAnchor(rawValue: 1 << 3)
    public static let center         = SnapAnchor(rawValue: 1 << 4)
    public static let trailing       = SnapAnchor(rawValue: 1 << 5)

    public static let bottomLeading  = SnapAnchor(rawValue: 1 << 6)
    public static let bottom         = SnapAnchor(rawValue: 1 << 7)
    public static let bottomTrailing = SnapAnchor(rawValue: 1 << 8)

    // MARK: - Convenience Sets

    /// The four corner anchors.
    public static let corners: SnapAnchor = [
        .topLeading, .topTrailing,
        .bottomLeading, .bottomTrailing,
    ]

    /// The four edge midpoint anchors.
    public static let edges: SnapAnchor = [
        .top, .bottom, .leading, .trailing,
    ]

    /// All nine anchors.
    public static let all: SnapAnchor = [.corners, .edges, .center]

    // MARK: - Enumeration

    /// All individual anchor values in a fixed order for iteration.
    static let allIndividual: [SnapAnchor] = [
        .topLeading, .top, .topTrailing,
        .leading, .center, .trailing,
        .bottomLeading, .bottom, .bottomTrailing,
    ]

    /// Returns only the individual anchors that are enabled in this set.
    var enabledAnchors: [SnapAnchor] {
        Self.allIndividual.filter { contains($0) }
    }

    /// Direction vector pointing toward the canvas center for an individual anchor.
    ///
    /// Each component is -1, 0, or 1. For example, `.topTrailing` returns
    /// `(-1, 1)` meaning left and down toward center.
    /// Only meaningful for single-anchor values (not combined sets).
    var inwardDirection: (x: CGFloat, y: CGFloat) {
        let isLeft = self == .topLeading || self == .leading || self == .bottomLeading
        let isRight = self == .topTrailing || self == .trailing || self == .bottomTrailing
        let isTop = self == .topLeading || self == .top || self == .topTrailing
        let isBottom = self == .bottomLeading || self == .bottom || self == .bottomTrailing

        let x: CGFloat = isLeft ? 1 : (isRight ? -1 : 0)
        let y: CGFloat = isTop ? 1 : (isBottom ? -1 : 0)
        return (x, y)
    }
}
