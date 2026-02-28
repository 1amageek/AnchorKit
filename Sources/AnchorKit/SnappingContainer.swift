import SwiftUI

/// A container that enables its children to snap to anchor positions.
///
/// Wrap your content in a `SnappingContainer` and apply `.snappable(id:anchor:)`
/// to each child that should participate in snap-to-anchor behavior.
///
/// ```swift
/// SnappingContainer(anchors: [.corners, .center]) {
///     ForEach($items) { $item in
///         FloatingCard(item: item)
///             .snappable(id: item.id, anchor: $item.anchor)
///     }
/// }
/// ```
///
/// The container manages canvas geometry, anchor-based positioning, drag
/// gestures, and stack layout for all snappable children.
public struct SnappingContainer<Content: View>: View {

    private let content: Content
    private let stackLayout: any StackLayout

    @State private var model: SnappingContainerModel

    /// Create a snapping container.
    ///
    /// - Parameters:
    ///   - anchors: The set of anchor positions where views can snap.
    ///     Defaults to `.corners` (four corners).
    ///   - insets: Edge insets for anchor position calculations.
    ///     Defaults to 16pt on all edges.
    ///   - stackLayout: Defines how items visually spread when sharing
    ///     the same anchor. Defaults to ``CascadeStackLayout``.
    ///   - content: The views to display. Apply `.snappable(id:anchor:)` to
    ///     each view that should snap.
    public init(
        anchors: SnapAnchor = .corners,
        insets: SnapInsets = SnapInsets(),
        stackLayout: some StackLayout = CascadeStackLayout(),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.stackLayout = stackLayout
        self._model = State(initialValue: SnappingContainerModel(
            anchors: anchors,
            insets: insets
        ))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: geometry.size, initial: true) { _, newSize in
                model.updateCanvasSize(newSize)
            }
        }
        .environment(\.snappingContainerModel, model)
        .environment(\.snappingStackLayout, stackLayout)
    }
}

// MARK: - Preview

private enum PreviewLayoutOption: String, CaseIterable {
    case cascade = "Cascade"
    case fan = "Fan"
    case arch = "Arch"
    case circle = "Circle"

    var layout: any StackLayout {
        switch self {
        case .cascade: CascadeStackLayout(spacing: 16)
        case .fan: FanStackLayout(angle: .degrees(8))
        case .arch: ArchStackLayout(radius: 80, spread: .degrees(40))
        case .circle: CircleStackLayout(radius: 50)
        }
    }
}

private struct PreviewCard: Identifiable {
    let id: Int
    let color: Color
    var anchor: SnapAnchor
}

private struct LayoutSwitcherPreview: View {

    @State private var selectedLayout: PreviewLayoutOption = .cascade
    @State private var cards: [PreviewCard] = [
        PreviewCard(id: 0, color: .red, anchor: .topLeading),
        PreviewCard(id: 1, color: .blue, anchor: .topLeading),
        PreviewCard(id: 2, color: .orange, anchor: .topTrailing),
        PreviewCard(id: 3, color: .green, anchor: .topTrailing),
        PreviewCard(id: 4, color: .purple, anchor: .center),
        PreviewCard(id: 5, color: .yellow, anchor: .center),
        PreviewCard(id: 6, color: .mint, anchor: .bottomLeading),
        PreviewCard(id: 7, color: .cyan, anchor: .bottomTrailing),
        PreviewCard(id: 8, color: .pink, anchor: .center),
    ]

    private let size = CGSize(width: 80, height: 80)

    var body: some View {
        VStack(spacing: 0) {
            SnappingContainer(anchors: [.corners, .center], stackLayout: selectedLayout.layout) {
                ForEach($cards) { $card in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(card.color.gradient)
                        .frame(width: size.width, height: size.height)
                        .overlay {
                            Text("\(card.id)")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        .snappable(id: card.id, anchor: $card.anchor, size: size)
                }
            }

            Picker("Layout", selection: $selectedLayout) {
                ForEach(PreviewLayoutOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding()
        }
    }
}


#Preview {
    LayoutSwitcherPreview()
}
