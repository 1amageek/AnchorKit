import SwiftUI

/// A container that enables its children to snap to anchor positions.
///
/// Wrap your content in a `SnappingContainer` and apply `.snappable(id:)`
/// to each child that should participate in snap-to-anchor behavior.
///
/// ```swift
/// SnappingContainer(anchors: [.corners, .center]) {
///     ForEach(items) { item in
///         FloatingCard(item: item)
///             .snappable(id: item.id)
///     }
/// }
/// ```
///
/// The container manages canvas geometry, initial positioning, drag
/// gestures, and collision avoidance for all snappable children.
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
    ///   - content: The views to display. Apply `.snappable(id:)` to
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

private struct LayoutSwitcherPreview: View {

    @State private var selectedLayout: PreviewLayoutOption = .cascade

    private let colors: [Color] = [.red, .blue, .orange, .green, .purple, .yellow, .mint, .cyan]
    private let size = CGSize(width: 80, height: 80)

    var body: some View {
        VStack(spacing: 0) {
            SnappingContainer(anchors: [.corners, .center], stackLayout: selectedLayout.layout) {
                ForEach(colors.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors[index].gradient)
                        .frame(width: size.width, height: size.height)
                        .overlay {
                            Text("\(index)")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        .snappable(id: index, size: size)
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
