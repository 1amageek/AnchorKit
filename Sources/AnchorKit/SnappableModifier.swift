import SwiftUI

/// View modifier that makes a view snappable within a ``SnappingContainer``.
///
/// Applies a drag gesture in the global coordinate space and snaps
/// to the nearest enabled anchor on drag end. Position animation (including
/// stack layout offsets) is driven by ``SpringPositionAnimator`` via
/// CADisplayLink, while scale and rotation use SwiftUI declarative animation.
///
/// To avoid interference between two independent spring oscillators,
/// the stack layout offset is folded into `.position()` (driven by Wave-style
/// spring physics) rather than a separate `.offset()` animated by SwiftUI.
/// On drag start/end, the model position is compensated so that the visual
/// position remains continuous even as the transform offset snaps.
struct SnappableModifier<ID: Hashable>: ViewModifier {

    let id: ID
    @Binding var anchor: SnapAnchor
    let explicitSize: CGSize?

    @Environment(\.snappingContainerModel) private var model
    @Environment(\.snappingStackLayout) private var stackLayout

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var measuredSize: CGSize = .zero
    @State private var animator = SpringPositionAnimator()

    private var effectiveSize: CGSize {
        explicitSize ?? measuredSize
    }

    func body(content: Content) -> some View {
        let key = AnyHashable(id)
        let isPositioned = model?.isPositioned(id: key) ?? false
        let transform = isDragging
            ? StackTransform.identity
            : (model?.stackTransform(for: key, layout: stackLayout) ?? .identity)
        let position = model?.position(for: key) ?? .zero

        content
            .background(sizeReader)
            // Scale and rotation: animated by SwiftUI (separate axes from position).
            .scaleEffect(transform.scale)
            .rotationEffect(transform.rotation)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: transform)
            // Position + stack offset: driven by SpringPositionAnimator.
            // Offset is folded into .position() so a single spring drives
            // the entire spatial motion, avoiding two-spring interference.
            .position(
                x: position.x + transform.offsetX + dragOffset.width,
                y: position.y + transform.offsetY + dragOffset.height
            )
            .zIndex(Double(model?.zIndex(for: key) ?? 0))
            .opacity(isPositioned ? 1 : 0)
            .gesture(dragGesture)
            .onAppear {
                model?.registerItem(id: key, size: effectiveSize, anchor: anchor)
            }
            .onDisappear {
                animator.stop()
                model?.unregisterItem(id: key)
            }
            .onChange(of: effectiveSize) { _, newSize in
                model?.registerItem(id: key, size: newSize, anchor: anchor)
            }
            .onChange(of: anchor) { _, newAnchor in
                guard !isDragging else { return }
                guard let model else { return }
                let key = AnyHashable(id)

                // Capture the current visual position before the anchor update.
                let oldPos = model.position(for: key)
                let oldTransform = model.stackTransform(for: key, layout: stackLayout)
                let oldVisual = CGPoint(
                    x: oldPos.x + oldTransform.offsetX,
                    y: oldPos.y + oldTransform.offsetY
                )

                model.updateAnchor(for: key, to: newAnchor)

                let newPos = model.position(for: key)
                let newTransform = model.stackTransform(for: key, layout: stackLayout)
                let newVisual = CGPoint(
                    x: newPos.x + newTransform.offsetX,
                    y: newPos.y + newTransform.offsetY
                )

                guard oldVisual != newVisual else { return }

                // Compensate so that visual = oldVisual at frame 0.
                // visual = model.position + newTransform.offset  =>
                // model.position = oldVisual - newTransform.offset
                let compensatedStart = CGPoint(
                    x: oldVisual.x - newTransform.offsetX,
                    y: oldVisual.y - newTransform.offsetY
                )
                model.setPosition(for: key, to: compensatedStart)

                animator.animate(
                    from: compensatedStart,
                    to: newPos,
                    velocity: .zero,
                    onUpdate: { position in
                        model.setPosition(for: key, to: position)
                    }
                )
            }
    }

    // MARK: - Size Measurement

    @ViewBuilder
    private var sizeReader: some View {
        if explicitSize == nil {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { measuredSize = geometry.size }
                    .onChange(of: geometry.size) { _, newSize in
                        measuredSize = newSize
                    }
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    // Compensate for the transform offset disappearing.
                    // Before drag: visual = model.position + transform.offset
                    // During drag: visual = model.position + 0 + dragOffset
                    // To keep visual continuous at dragOffset=0, absorb the
                    // offset into model.position.
                    if let model {
                        let key = AnyHashable(id)
                        let currentTransform = model.stackTransform(for: key, layout: stackLayout)
                        if currentTransform.offsetX != 0 || currentTransform.offsetY != 0 {
                            let pos = model.position(for: key)
                            model.setPosition(for: key, to: CGPoint(
                                x: pos.x + currentTransform.offsetX,
                                y: pos.y + currentTransform.offsetY
                            ))
                        }
                    }
                    isDragging = true
                    animator.stop()
                    model?.bringToFront(id: AnyHashable(id))
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard let model else { return }
                let key = AnyHashable(id)
                let currentPosition = model.position(for: key)
                let draggedPosition = CGPoint(
                    x: currentPosition.x + dragOffset.width,
                    y: currentPosition.y + dragOffset.height
                )
                let (resolvedAnchor, target) = model.resolveSnapTarget(
                    for: key,
                    currentPosition: draggedPosition,
                    velocity: value.velocity
                )

                // Update anchor and stop dragging so that the body picks up
                // the computed stack transform on the next evaluation.
                anchor = resolvedAnchor
                isDragging = false

                // Compute the transform offset that will now be applied
                // (isDragging is false, so body uses the real transform).
                let finalTransform = model.stackTransform(for: key, layout: stackLayout)

                // Compensate: set model position so that the visual stays
                // at draggedPosition even though the offset just snapped.
                //   visual = model.position + finalTransform.offset = draggedPosition
                //   => model.position = draggedPosition - finalTransform.offset
                let compensatedStart = CGPoint(
                    x: draggedPosition.x - finalTransform.offsetX,
                    y: draggedPosition.y - finalTransform.offsetY
                )
                model.setPosition(for: key, to: compensatedStart)
                dragOffset = .zero

                animator.animate(
                    from: compensatedStart,
                    to: target,
                    velocity: CGPoint(
                        x: value.velocity.width,
                        y: value.velocity.height
                    ),
                    onUpdate: { position in
                        model.setPosition(for: key, to: position)
                    }
                )
            }
    }
}

// MARK: - View Extension

extension View {

    /// Make this view snappable within a ``SnappingContainer``.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this snappable item.
    ///   - anchor: Binding to the anchor this item belongs to.
    ///     Updated when the item snaps to a new anchor after a drag.
    ///   - size: Explicit size for snap calculations. If `nil`, the view's
    ///           intrinsic size is measured automatically.
    public func snappable<ID: Hashable>(
        id: ID,
        anchor: Binding<SnapAnchor>,
        size: CGSize? = nil
    ) -> some View {
        modifier(SnappableModifier(id: id, anchor: anchor, explicitSize: size))
    }
}

// MARK: - Environment Keys

struct SnappingContainerModelKey: EnvironmentKey {
    static let defaultValue: SnappingContainerModel? = nil
}

struct SnappingStackLayoutKey: EnvironmentKey {
    static let defaultValue: any StackLayout = CascadeStackLayout()
}

extension EnvironmentValues {
    var snappingContainerModel: SnappingContainerModel? {
        get { self[SnappingContainerModelKey.self] }
        set { self[SnappingContainerModelKey.self] = newValue }
    }

    var snappingStackLayout: any StackLayout {
        get { self[SnappingStackLayoutKey.self] }
        set { self[SnappingStackLayoutKey.self] = newValue }
    }
}
