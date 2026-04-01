import QuartzCore

/// Drives spring-based position animation on the main thread using CADisplayLink.
///
/// Each frame, the spring physics model computes a new position and delivers it
/// through the `onUpdate` callback. The animation stops automatically when the
/// settling duration is reached.
///
/// Stopping mid-animation preserves the current model position, enabling seamless
/// drag-interrupt during in-flight snap animations.
@MainActor
final class SpringPositionAnimator {

    private var displayLink: CADisplayLink?
    private var proxy: DisplayLinkProxy?

    private var currentValue: CGPoint = .zero
    private var targetValue: CGPoint = .zero
    private var currentVelocity: CGPoint = .zero
    private var spring: Spring = .snappy
    private var startTime: CFTimeInterval = 0

    private var onUpdate: ((CGPoint) -> Void)?

    nonisolated init() {}

    /// Start animating from `current` to `target` with initial `velocity`.
    ///
    /// Any in-flight animation is stopped before starting the new one.
    /// The `onUpdate` callback fires each display frame with the interpolated position.
    func animate(
        from current: CGPoint,
        to target: CGPoint,
        velocity: CGPoint,
        spring: Spring = .snappy,
        onUpdate: @escaping (CGPoint) -> Void
    ) {
        stop()
        self.currentValue = current
        self.targetValue = target
        self.currentVelocity = velocity
        self.spring = spring
        self.onUpdate = onUpdate
        self.startTime = CACurrentMediaTime()

        let proxy = DisplayLinkProxy()
        proxy.animator = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step(_:)))
        link.add(to: .main, forMode: .common)
        self.proxy = proxy
        self.displayLink = link
    }

    /// Stop the current animation immediately.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        proxy?.animator = nil
        proxy = nil
        onUpdate = nil
    }

    fileprivate func tick(dt: TimeInterval) {
        guard dt > 0 else { return }

        guard spring.response > 0 else {
            onUpdate?(targetValue)
            stop()
            return
        }

        let (newValue, newVelocity) = spring.updatedValue(
            value: currentValue, target: targetValue, velocity: currentVelocity, dt: dt
        )
        currentValue = newValue
        currentVelocity = newVelocity

        let elapsed = CACurrentMediaTime() - startTime
        if elapsed >= spring.settlingDuration {
            onUpdate?(targetValue)
            stop()
        } else {
            onUpdate?(newValue)
        }
    }
}

// MARK: - Display Link Proxy

/// Weak-reference proxy that forwards CADisplayLink callbacks to the animator.
///
/// When the animator is deallocated, the proxy automatically invalidates
/// the display link to prevent orphaned timers.
private final class DisplayLinkProxy: NSObject {

    weak var animator: SpringPositionAnimator?

    @objc func step(_ displayLink: CADisplayLink) {
        let dt = displayLink.targetTimestamp - displayLink.timestamp
        guard let animator else {
            displayLink.invalidate()
            return
        }
        MainActor.assumeIsolated {
            animator.tick(dt: dt)
        }
    }
}
