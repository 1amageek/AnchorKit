import CoreGraphics
import Foundation

/// Spring physics model for driving animations.
///
/// Configured with a damping ratio and frequency response. The damping ratio
/// controls oscillation (1.0 = critically damped, < 1.0 = underdamped/bouncy).
/// The response controls speed (lower = faster).
///
/// Based on the spring-mass-damper model from WWDC 2018 "Designing Fluid Interfaces".
struct Spring: Sendable, Equatable {

    let dampingRatio: CGFloat
    let response: CGFloat
    let stiffness: CGFloat
    let mass: CGFloat
    let dampingCoefficient: CGFloat
    let settlingDuration: TimeInterval

    /// Create a spring with damping ratio and frequency response.
    ///
    /// - Parameters:
    ///   - dampingRatio: Oscillation amount. 1.0 = no bounce, < 1.0 = bouncy.
    ///   - response: Animation speed. Lower = faster. One period of the undamped system in seconds.
    ///   - mass: Mass attached to the spring. Defaults to 1.0.
    init(dampingRatio: CGFloat, response: CGFloat, mass: CGFloat = 1.0) {
        precondition(dampingRatio >= 0)
        precondition(response >= 0)
        self.dampingRatio = dampingRatio
        self.response = response
        self.mass = mass
        self.stiffness = Self.computeStiffness(response: response, mass: mass)
        let rawCoefficient = Self.computeDampingCoefficient(
            dampingRatio: dampingRatio, response: response, mass: mass
        )
        self.dampingCoefficient = Self.rubberband(value: rawCoefficient, range: 0...60, interval: 15)
        self.settlingDuration = Self.computeSettlingTime(
            dampingRatio: dampingRatio, stiffness: self.stiffness, mass: mass
        )
    }

    // MARK: - Presets

    /// Slightly underdamped spring suitable for snap animations.
    static let snappy = Spring(dampingRatio: 0.85, response: 0.35)

    /// Responsive spring for interactive drag animations.
    static let interactive = Spring(dampingRatio: 0.8, response: 0.20)

    // MARK: - Spring Update

    /// Compute one step of spring physics for a scalar value.
    func updatedValue(
        value: CGFloat,
        target: CGFloat,
        velocity: CGFloat,
        dt: TimeInterval
    ) -> (value: CGFloat, velocity: CGFloat) {
        precondition(response > 0, "Cannot compute spring physics with zero response.")
        let displacement = value - target
        let springForce = -stiffness * displacement
        let dampingForce = dampingCoefficient * velocity
        let acceleration = (springForce - dampingForce) / mass
        let newVelocity = velocity + acceleration * dt
        let newValue = value + newVelocity * dt
        return (newValue, newVelocity)
    }

    /// Compute one step of spring physics for a 2D point.
    func updatedValue(
        value: CGPoint,
        target: CGPoint,
        velocity: CGPoint,
        dt: TimeInterval
    ) -> (value: CGPoint, velocity: CGPoint) {
        let (newX, newVX) = updatedValue(
            value: value.x, target: target.x, velocity: velocity.x, dt: dt
        )
        let (newY, newVY) = updatedValue(
            value: value.y, target: target.y, velocity: velocity.y, dt: dt
        )
        return (CGPoint(x: newX, y: newY), CGPoint(x: newVX, y: newVY))
    }

    // MARK: - Derived Constants

    private static func computeStiffness(response: CGFloat, mass: CGFloat) -> CGFloat {
        let omega = 2.0 * .pi / response
        return omega * omega * mass
    }

    private static func computeDampingCoefficient(
        dampingRatio: CGFloat, response: CGFloat, mass: CGFloat
    ) -> CGFloat {
        4.0 * .pi * dampingRatio * mass / response
    }

    private static let logSettlingThreshold = log(0.0001)

    private static func computeSettlingTime(
        dampingRatio: CGFloat, stiffness: CGFloat, mass: CGFloat
    ) -> CGFloat {
        if stiffness == .infinity { return 1.0 }
        if dampingRatio >= 1.0 {
            let nearCritical = computeSettlingTime(
                dampingRatio: 1.0 - .ulpOfOne, stiffness: stiffness, mass: mass
            )
            return nearCritical * 1.25
        }
        let wn = sqrt(stiffness / mass)
        return -logSettlingThreshold / (dampingRatio * wn)
    }

    /// Soft-clamp a value using UIScrollView-style rubber banding.
    private static func rubberband(
        value: CGFloat, range: ClosedRange<CGFloat>, interval: CGFloat
    ) -> CGFloat {
        if range.contains(value) { return value }
        let c: CGFloat = 0.55
        if value > range.upperBound {
            let x = value - range.upperBound
            let b = (1.0 - (1.0 / ((x * c / interval) + 1.0))) * interval
            return range.upperBound + b
        } else {
            let x = range.lowerBound - value
            let b = (1.0 - (1.0 / ((x * c / interval) + 1.0))) * interval
            return range.lowerBound - b
        }
    }
}
