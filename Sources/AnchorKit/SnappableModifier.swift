import SwiftUI

/// View modifier that makes a view snappable within a ``SnappingContainer``.
///
/// Applies a drag gesture in the global coordinate space and snaps
/// to the nearest enabled anchor on drag end.
struct SnappableModifier<ID: Hashable>: ViewModifier {

    let id: ID
    let explicitSize: CGSize?

    @Environment(\.snappingContainerModel) private var model
    @Environment(\.snappingStackLayout) private var stackLayout

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var measuredSize: CGSize = .zero

    private var effectiveSize: CGSize {
        explicitSize ?? measuredSize
    }

    private var transitionAnimation: Animation {
        .spring(duration: 0.35, bounce: 0.15)
    }

    func body(content: Content) -> some View {
        let key = AnyHashable(id)
        let isPositioned = model?.isPositioned(id: key) ?? false
        let transform = isDragging ? .identity : (model?.stackTransform(for: key, layout: stackLayout) ?? .identity)
        let position = model?.position(for: key) ?? .zero

        content
            .background(sizeReader)
            .scaleEffect(transform.scale)
            .rotationEffect(transform.rotation)
            .position(
                x: position.x + transform.offsetX + dragOffset.width,
                y: position.y + transform.offsetY + dragOffset.height
            )
            .zIndex(Double(model?.zIndex(for: key) ?? 0))
            .opacity(isPositioned ? 1 : 0)
            .gesture(dragGesture)
            .animation(transitionAnimation, value: transform)
            .onAppear {
                model?.registerItem(id: key, size: effectiveSize)
            }
            .onDisappear {
                model?.unregisterItem(id: key)
            }
            .onChange(of: effectiveSize) { _, newSize in
                model?.registerItem(id: key, size: newSize)
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
                    isDragging = true
                    model?.bringToFront(id: AnyHashable(id))
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false
                guard let model else { return }
                let key = AnyHashable(id)
                let currentPosition = model.position(for: key)
                let draggedPosition = CGPoint(
                    x: currentPosition.x + dragOffset.width,
                    y: currentPosition.y + dragOffset.height
                )
                let target = model.resolveSnapTarget(
                    for: key,
                    currentPosition: draggedPosition,
                    velocity: value.velocity
                )
                // Two-step commit: instant position update, then animate to snap target.
                model.setPosition(for: key, to: draggedPosition)
                dragOffset = .zero
                withAnimation(transitionAnimation) {
                    model.setPosition(for: key, to: target)
                }
            }
    }
}

// MARK: - View Extension

extension View {

    /// Make this view snappable within a ``SnappingContainer``.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this snappable item.
    ///   - size: Explicit size for snap calculations. If `nil`, the view's
    ///           intrinsic size is measured automatically.
    public func snappable<ID: Hashable>(id: ID, size: CGSize? = nil) -> some View {
        modifier(SnappableModifier(id: id, explicitSize: size))
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
