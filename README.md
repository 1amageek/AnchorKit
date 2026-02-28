# AnchorKit

A SwiftUI library for snap-to-anchor positioning of draggable views.

Views snap to predefined anchor points with velocity-based projection, and multiple items sharing an anchor are visually organized through pluggable stack layouts.

## Features

- **Snap-to-Anchor** — Drag views and release; they snap to the nearest anchor using velocity projection (WWDC 2018 Fluid Interfaces)
- **Anchor Binding** — Each item's anchor is a `Binding<SnapAnchor>`, enabling save and restore of positions
- **Stack Layouts** — Multiple items at the same anchor spread visually:
  - `CascadeStackLayout` — Diagonal offset like stacked papers
  - `FanStackLayout` — Rotational spread like a hand of cards
  - `ArchStackLayout` — Arc-based arrangement
  - `CircleStackLayout` — Circular distribution
- **Direction-Aware** — Layouts adapt to the anchor position (e.g., cascade inward, not off-screen)
- **Custom Layouts** — Implement `StackLayout` protocol for your own patterns
- **Codable Anchors** — `SnapAnchor` conforms to `Codable` for persistence

## Requirements

- iOS 18+ / macOS 15+
- Swift 6.2+

## Installation

Add AnchorKit via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/AnchorKit.git", from: "0.1.0")
]
```

## Usage

```swift
import AnchorKit

struct Item: Identifiable {
    let id: Int
    let color: Color
    var anchor: SnapAnchor
}

struct ContentView: View {

    @State private var items: [Item] = [
        Item(id: 0, color: .red, anchor: .topLeading),
        Item(id: 1, color: .blue, anchor: .topTrailing),
        Item(id: 2, color: .green, anchor: .bottomLeading),
        Item(id: 3, color: .orange, anchor: .bottomTrailing),
    ]

    var body: some View {
        SnappingContainer(anchors: [.corners, .center]) {
            ForEach($items) { $item in
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.color.gradient)
                    .frame(width: 80, height: 80)
                    .snappable(id: item.id, anchor: $item.anchor)
            }
        }
    }
}
```

### Custom Stack Layout

```swift
SnappingContainer(
    anchors: .all,
    stackLayout: FanStackLayout(angle: .degrees(8))
) {
    // ...
}
```

### Persisting Anchor Assignments

`SnapAnchor` conforms to `Codable`, so you can encode and decode anchor assignments:

```swift
// Save
let data = try JSONEncoder().encode(items.map(\.anchor))

// Restore
let anchors = try JSONDecoder().decode([SnapAnchor].self, from: data)
```

## License

MIT License. See [LICENSE](LICENSE) for details.
