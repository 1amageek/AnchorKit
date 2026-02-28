import CoreGraphics
import Foundation
import Testing

@testable import AnchorKit

// MARK: - SnapAnchor Tests

@Suite struct SnapAnchorTests {

    @Test func cornersContainsFourAnchors() {
        let anchors = SnapAnchor.corners.enabledAnchors
        #expect(anchors.count == 4)
        #expect(SnapAnchor.corners.contains(.topLeading))
        #expect(SnapAnchor.corners.contains(.topTrailing))
        #expect(SnapAnchor.corners.contains(.bottomLeading))
        #expect(SnapAnchor.corners.contains(.bottomTrailing))
    }

    @Test func edgesContainsFourAnchors() {
        let anchors = SnapAnchor.edges.enabledAnchors
        #expect(anchors.count == 4)
        #expect(SnapAnchor.edges.contains(.top))
        #expect(SnapAnchor.edges.contains(.bottom))
        #expect(SnapAnchor.edges.contains(.leading))
        #expect(SnapAnchor.edges.contains(.trailing))
    }

    @Test func allContainsNineAnchors() {
        let anchors = SnapAnchor.all.enabledAnchors
        #expect(anchors.count == 9)
    }

    @Test func setOperations() {
        let combined: SnapAnchor = [.corners, .center]
        #expect(combined.enabledAnchors.count == 5)
        #expect(combined.contains(.topLeading))
        #expect(combined.contains(.center))
        #expect(!combined.contains(.top))
    }

    @Test func codableRoundTrip() throws {
        let original: SnapAnchor = .topTrailing
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnapAnchor.self, from: data)
        #expect(decoded == original)
    }

    @Test func codableRoundTripCombined() throws {
        let original: SnapAnchor = [.corners, .center]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnapAnchor.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - SnapGeometry Tests

@Suite struct SnapGeometryTests {

    let canvas = CGSize(width: 800, height: 600)
    let content = CGSize(width: 100, height: 100)
    let insets = SnapInsets(all: 16)

    // MARK: - Anchor Positions

    @Test func topLeadingAnchorPosition() {
        let pos = SnapGeometry.anchorPosition(
            .topLeading, in: canvas, contentSize: content, insets: insets
        )
        // halfW(50) + leading(16) = 66
        #expect(pos.x == 66)
        // halfH(50) + top(16) = 66
        #expect(pos.y == 66)
    }

    @Test func bottomTrailingAnchorPosition() {
        let pos = SnapGeometry.anchorPosition(
            .bottomTrailing, in: canvas, contentSize: content, insets: insets
        )
        // canvasW(800) - halfW(50) - trailing(16) = 734
        #expect(pos.x == 734)
        // canvasH(600) - halfH(50) - bottom(16) = 534
        #expect(pos.y == 534)
    }

    @Test func centerAnchorPosition() {
        let pos = SnapGeometry.anchorPosition(
            .center, in: canvas, contentSize: content, insets: insets
        )
        #expect(pos.x == 400)
        #expect(pos.y == 300)
    }

    @Test func topAnchorPosition() {
        let pos = SnapGeometry.anchorPosition(
            .top, in: canvas, contentSize: content, insets: insets
        )
        #expect(pos.x == 400)  // center X
        #expect(pos.y == 66)   // top Y
    }

    @Test func trailingAnchorPosition() {
        let pos = SnapGeometry.anchorPosition(
            .trailing, in: canvas, contentSize: content, insets: insets
        )
        #expect(pos.x == 734)  // right X
        #expect(pos.y == 300)  // center Y
    }

    @Test func anchorPositionsCountMatchesEnabledAnchors() {
        let positions = SnapGeometry.anchorPositions(
            for: .corners, in: canvas, contentSize: content, insets: insets
        )
        #expect(positions.count == 4)

        let allPositions = SnapGeometry.anchorPositions(
            for: .all, in: canvas, contentSize: content, insets: insets
        )
        #expect(allPositions.count == 9)
    }

    // MARK: - Canvas smaller than content

    @Test func centersWhenCanvasTooSmall() {
        let smallCanvas = CGSize(width: 80, height: 80)
        let largeContent = CGSize(width: 200, height: 200)
        let pos = SnapGeometry.anchorPosition(
            .topLeading, in: smallCanvas, contentSize: largeContent, insets: insets
        )
        // Canvas is smaller than content: centers on both axes
        #expect(pos.x == 40)  // smallCanvas.width / 2
        #expect(pos.y == 40)  // smallCanvas.height / 2
    }

    // MARK: - Nearest Anchor

    @Test func nearestAnchorFindsClosest() {
        // Point near top-right area
        let point = CGPoint(x: 700, y: 80)
        let (anchor, _) = SnapGeometry.nearestAnchor(
            to: point, from: .corners, in: canvas, contentSize: content, insets: insets
        )
        #expect(anchor == .topTrailing)
    }

    @Test func nearestAnchorWithSingleAnchor() {
        let point = CGPoint(x: 100, y: 100)
        let (anchor, position) = SnapGeometry.nearestAnchor(
            to: point, from: .center, in: canvas, contentSize: content, insets: insets
        )
        #expect(anchor == .center)
        #expect(position.x == 400)
        #expect(position.y == 300)
    }

    // MARK: - Clamping

    @Test func clampedKeepsWithinBounds() {
        let outOfBounds = CGPoint(x: -100, y: 700)
        let clamped = SnapGeometry.clamped(
            outOfBounds, in: canvas, contentSize: content, insets: insets
        )
        // minX = 66, minY = 66, maxX = 734, maxY = 534
        #expect(clamped.x == 66)
        #expect(clamped.y == 534)
    }

    @Test func clampedPassthroughWhenWithinBounds() {
        let valid = CGPoint(x: 400, y: 300)
        let clamped = SnapGeometry.clamped(
            valid, in: canvas, contentSize: content, insets: insets
        )
        #expect(clamped.x == 400)
        #expect(clamped.y == 300)
    }

    // MARK: - Overlap Detection

    @Test func overlapDetected() {
        let a = CGPoint(x: 100, y: 100)
        let b = CGPoint(x: 130, y: 130)
        let size = CGSize(width: 100, height: 100)
        #expect(SnapGeometry.itemsOverlap(a, b, sizeA: size, sizeB: size))
    }

    @Test func noOverlapWhenFarApart() {
        let a = CGPoint(x: 100, y: 100)
        let b = CGPoint(x: 400, y: 400)
        let size = CGSize(width: 100, height: 100)
        #expect(!SnapGeometry.itemsOverlap(a, b, sizeA: size, sizeB: size))
    }

    @Test func overlapWithDifferentSizes() {
        let a = CGPoint(x: 100, y: 100)
        let b = CGPoint(x: 170, y: 100)
        let sizeA = CGSize(width: 100, height: 100)
        let sizeB = CGSize(width: 50, height: 50)
        // halfWidthSum = (100+50)/2 = 75, distance = 70 → overlap
        #expect(SnapGeometry.itemsOverlap(a, b, sizeA: sizeA, sizeB: sizeB))
    }

    // MARK: - Deceleration Projection

    @Test func projectionIsPositiveForPositiveVelocity() {
        let projected = SnapGeometry.project(initialVelocity: 1000)
        #expect(projected > 0)
    }

    @Test func projectionIsNegativeForNegativeVelocity() {
        let projected = SnapGeometry.project(initialVelocity: -1000)
        #expect(projected < 0)
    }

    @Test func projectionIsZeroForZeroVelocity() {
        let projected = SnapGeometry.project(initialVelocity: 0)
        #expect(projected == 0)
    }
}

// MARK: - SnappingContainerModel Tests

@Suite struct SnappingContainerModelTests {

    @Test @MainActor func registerItemPositionsAtDesignatedAnchor() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        model.registerItem(
            id: AnyHashable("a"),
            size: CGSize(width: 100, height: 100),
            anchor: .bottomTrailing
        )

        #expect(model.items.count == 1)
        #expect(model.isPositioned(id: AnyHashable("a")))
        let pos = model.position(for: AnyHashable("a"))
        #expect(abs(pos.x - 734) < 1)
        #expect(abs(pos.y - 534) < 1)
    }

    @Test @MainActor func unregisterItem() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        model.registerItem(
            id: AnyHashable("a"),
            size: CGSize(width: 100, height: 100),
            anchor: .topLeading
        )
        model.unregisterItem(id: AnyHashable("a"))

        #expect(model.items.isEmpty)
    }

    @Test @MainActor func itemsAtDifferentAnchorsGetDifferentPositions() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)
        model.registerItem(id: AnyHashable("b"), size: size, anchor: .bottomTrailing)

        let posA = model.position(for: AnyHashable("a"))
        let posB = model.position(for: AnyHashable("b"))
        let samePosition = abs(posA.x - posB.x) < 1 && abs(posA.y - posB.y) < 1
        #expect(!samePosition)
    }

    @Test @MainActor func itemsAtSameAnchorGetSamePosition() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)
        model.registerItem(id: AnyHashable("b"), size: size, anchor: .topLeading)

        let posA = model.position(for: AnyHashable("a"))
        let posB = model.position(for: AnyHashable("b"))
        #expect(abs(posA.x - posB.x) < 1)
        #expect(abs(posA.y - posB.y) < 1)
    }

    @Test @MainActor func bringToFrontUpdatesZIndex() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        model.registerItem(
            id: AnyHashable("a"),
            size: CGSize(width: 100, height: 100),
            anchor: .topLeading
        )
        model.registerItem(
            id: AnyHashable("b"),
            size: CGSize(width: 100, height: 100),
            anchor: .topTrailing
        )

        let initialZA = model.zIndex(for: AnyHashable("a"))
        model.bringToFront(id: AnyHashable("a"))
        let newZA = model.zIndex(for: AnyHashable("a"))
        #expect(newZA > initialZA)
    }

    @Test @MainActor func resolveSnapTargetReturnsAnchorAndPosition() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)

        let (anchor, position) = model.resolveSnapTarget(
            for: AnyHashable("a"),
            currentPosition: CGPoint(x: 700, y: 500),
            velocity: .zero
        )
        #expect(anchor == .bottomTrailing)
        #expect(abs(position.x - 734) < 1)
        #expect(abs(position.y - 534) < 1)
    }

    @Test @MainActor func resolveSnapTargetUpdatesStoredAnchor() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)

        _ = model.resolveSnapTarget(
            for: AnyHashable("a"),
            currentPosition: CGPoint(x: 700, y: 500),
            velocity: .zero
        )
        #expect(model.items.first?.anchor == .bottomTrailing)
    }

    @Test @MainActor func resolveSnapTargetWithVelocity() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)

        let (anchor, position) = model.resolveSnapTarget(
            for: AnyHashable("a"),
            currentPosition: CGPoint(x: 400, y: 300),
            velocity: CGSize(width: 2000, height: 2000)
        )
        // Velocity projects toward bottom-right
        #expect(anchor == .bottomTrailing)
        #expect(abs(position.x - 734) < 1)
        #expect(abs(position.y - 534) < 1)
    }

    @Test @MainActor func itemsPositionedAfterCanvasSizeSet() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.registerItem(
            id: AnyHashable("a"),
            size: CGSize(width: 100, height: 100),
            anchor: .topLeading
        )
        #expect(!model.isPositioned(id: AnyHashable("a")))

        model.updateCanvasSize(CGSize(width: 800, height: 600))
        #expect(model.isPositioned(id: AnyHashable("a")))
    }

    @Test @MainActor func canvasResizeKeepsAnchorAssignment() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .bottomTrailing)

        // Resize to smaller canvas
        model.updateCanvasSize(CGSize(width: 400, height: 300))
        let posAfter = model.position(for: AnyHashable("a"))

        // Anchor stays bottomTrailing, position recomputed for new canvas
        #expect(model.items.first?.anchor == .bottomTrailing)
        // New bottomTrailing = (400-50-16, 300-50-16) = (334, 234)
        #expect(abs(posAfter.x - 334) < 1)
        #expect(abs(posAfter.y - 234) < 1)
    }

    @Test @MainActor func updateAnchorRepositionsItem() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)

        let posBefore = model.position(for: AnyHashable("a"))
        #expect(abs(posBefore.x - 66) < 1)
        #expect(abs(posBefore.y - 66) < 1)

        model.updateAnchor(for: AnyHashable("a"), to: .bottomTrailing)
        let posAfter = model.position(for: AnyHashable("a"))
        #expect(abs(posAfter.x - 734) < 1)
        #expect(abs(posAfter.y - 534) < 1)
        #expect(model.items.first?.anchor == .bottomTrailing)
    }

    @Test @MainActor func updateAnchorNoOpWhenSame() {
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)

        let posBefore = model.position(for: AnyHashable("a"))
        model.updateAnchor(for: AnyHashable("a"), to: .topLeading)
        let posAfter = model.position(for: AnyHashable("a"))
        #expect(posBefore.x == posAfter.x)
        #expect(posBefore.y == posAfter.y)
    }

    @Test @MainActor func stackTransformUsesLayout() {
        let layout = CascadeStackLayout(spacing: 20)
        let model = SnappingContainerModel(
            anchors: .corners, insets: SnapInsets(all: 16)
        )
        model.updateCanvasSize(CGSize(width: 800, height: 600))
        let size = CGSize(width: 100, height: 100)
        model.registerItem(id: AnyHashable("a"), size: size, anchor: .topLeading)
        model.registerItem(id: AnyHashable("b"), size: size, anchor: .topLeading)

        // a has lower z-index (registered first), so a is depth 0 (identity)
        let transformA = model.stackTransform(for: AnyHashable("a"), layout: layout)
        #expect(transformA == .identity)

        // b is depth 1 (arrived later, gets offset)
        let transformB = model.stackTransform(for: AnyHashable("b"), layout: layout)
        #expect(transformB.offsetX == 20)
        #expect(transformB.offsetY == 20)
    }
}

// MARK: - StackLayout Tests

@Suite struct StackLayoutTests {

    @Test func cascadeLayoutTopLeading() {
        let layout = CascadeStackLayout(spacing: 10)
        #expect(layout.transform(at: 0, count: 3, anchor: .topLeading) == .identity)
        let t1 = layout.transform(at: 1, count: 3, anchor: .topLeading)
        #expect(t1.offsetX == 10)
        #expect(t1.offsetY == 10)
        let t2 = layout.transform(at: 2, count: 3, anchor: .topLeading)
        #expect(t2.offsetX == 20)
        #expect(t2.offsetY == 20)
    }

    @Test func cascadeLayoutTopTrailingFlipsX() {
        let layout = CascadeStackLayout(spacing: 10)
        let t1 = layout.transform(at: 1, count: 3, anchor: .topTrailing)
        #expect(t1.offsetX == -10)
        #expect(t1.offsetY == 10)
    }

    @Test func cascadeLayoutBottomTrailingFlipsBoth() {
        let layout = CascadeStackLayout(spacing: 10)
        let t1 = layout.transform(at: 1, count: 3, anchor: .bottomTrailing)
        #expect(t1.offsetX == -10)
        #expect(t1.offsetY == -10)
    }

    @Test func fanLayoutAllItemsParticipate() {
        let layout = FanStackLayout(angle: .degrees(5))
        // count=3: all items get rotation, centered around middle
        let t0 = layout.transform(at: 0, count: 3, anchor: .topLeading)
        let t1 = layout.transform(at: 1, count: 3, anchor: .topLeading)
        let t2 = layout.transform(at: 2, count: 3, anchor: .topLeading)
        #expect(t0.rotation == .degrees(-5))
        #expect(t1.rotation == .degrees(0))
        #expect(t2.rotation == .degrees(5))
    }

    @Test func fanLayoutTopTrailingFlipsRotation() {
        let layout = FanStackLayout(angle: .degrees(5))
        let t0 = layout.transform(at: 0, count: 3, anchor: .topTrailing)
        let t2 = layout.transform(at: 2, count: 3, anchor: .topTrailing)
        // Direction flipped at trailing side
        #expect(t0.rotation == .degrees(5))
        #expect(t2.rotation == .degrees(-5))
    }

    @Test func circleLayoutAllItemsOnCircle() {
        let layout = CircleStackLayout(radius: 40)
        // count=3 at topLeading: all items on the circle
        let t0 = layout.transform(at: 0, count: 3, anchor: .topLeading)
        // Depth 0 points inward (toward bottom-right for topLeading)
        #expect(t0.offsetX > 0)
        #expect(t0.offsetY > 0)
        // All items have non-zero offset
        for depth in 0..<3 {
            let t = layout.transform(at: depth, count: 3, anchor: .topLeading)
            let distance = sqrt(t.offsetX * t.offsetX + t.offsetY * t.offsetY)
            #expect(abs(distance - 40) < 0.01)
        }
    }

    @Test func circleLayoutTopTrailingPointsInward() {
        let layout = CircleStackLayout(radius: 40)
        let t0 = layout.transform(at: 0, count: 3, anchor: .topTrailing)
        // Depth 0 points inward (toward bottom-left for topTrailing)
        #expect(t0.offsetX < 0)
        #expect(t0.offsetY > 0)
    }

    @Test func archLayoutAllItemsParticipate() {
        let layout = ArchStackLayout(radius: 60, spread: .degrees(30))
        // count=3: depths 0 and 2 are symmetric, depth 1 is at center
        let t0 = layout.transform(at: 0, count: 3, anchor: .topLeading)
        let t1 = layout.transform(at: 1, count: 3, anchor: .topLeading)
        let t2 = layout.transform(at: 2, count: 3, anchor: .topLeading)
        #expect(abs(t0.offsetX + t2.offsetX) < 0.01)
        #expect(abs(t1.offsetX) < 0.01)
        // Depth 0 has non-zero rotation
        #expect(t0.rotation != .zero)
    }

    @Test func archLayoutTwoItemsBothHaveTransform() {
        let layout = ArchStackLayout(radius: 60, spread: .degrees(30))
        let t0 = layout.transform(at: 0, count: 2, anchor: .topLeading)
        let t1 = layout.transform(at: 1, count: 2, anchor: .topLeading)
        // Both items have visible offset and rotation
        #expect(t0.rotation != .zero)
        #expect(t1.rotation != .zero)
        // Symmetric
        #expect(abs(t0.offsetX + t1.offsetX) < 0.01)
    }

    @Test func archLayoutBottomTrailingFlipsDirection() {
        let layout = ArchStackLayout(radius: 60, spread: .degrees(30))
        let topLeading = layout.transform(at: 2, count: 3, anchor: .topLeading)
        let bottomTrailing = layout.transform(at: 2, count: 3, anchor: .bottomTrailing)
        // Y direction should be flipped
        #expect(topLeading.offsetY > 0)
        #expect(bottomTrailing.offsetY < 0)
    }

    @Test func singleItemAlwaysIdentity() {
        let layouts: [any StackLayout] = [
            CascadeStackLayout(),
            FanStackLayout(),
            ArchStackLayout(),
            CircleStackLayout(),
        ]
        for layout in layouts {
            #expect(layout.transform(at: 0, count: 1, anchor: .topLeading) == .identity)
        }
    }
}
