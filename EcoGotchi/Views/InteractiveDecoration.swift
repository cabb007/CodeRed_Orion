import SwiftUI

struct InteractiveDecoration: View {
    let decoration: Decoration
    let home: CGPoint
    let playground: CGRect
    let size: CGFloat
    let placement: DecorationPlacement
    let isSelected: Bool
    let showLabel: Bool
    let sceneActive: Bool
    let onSelect: () -> Void
    let onMove: (Double, Double) -> Void
    let onLock: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var gestureActive = false
    @State private var dragOrigin: CGPoint?
    @State private var translation = CGSize.zero

    private var basePosition: CGPoint {
        guard let x = placement.x, let y = placement.y, x.isFinite, y.isFinite else {
            return PetMotion.bounded(home, in: playground, size: size)
        }
        return PetMotion.bounded(CGPoint(x: playground.minX + x * playground.width,
                                         y: playground.minY + y * playground.height), in: playground, size: size)
    }
    private var center: CGPoint {
        let origin = dragOrigin ?? basePosition
        return PetMotion.bounded(CGPoint(x: origin.x + translation.width, y: origin.y + translation.height),
                                 in: playground, size: size)
    }

    var body: some View {
        PixelSprite(sprite: GameSprite(rawValue: decoration.id) ?? .flowers, size: size)
            .scaleEffect(dragOrigin != nil && !reduceMotion ? 1.08 : 1)
            .frame(width: max(60, size), height: max(60, size))
            .contentShape(Rectangle())
            .overlay {
                if isSelected {
                    PixelFrame().stroke(Palette.forest.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .padding(-4).allowsHitTesting(false)
                }
            }
            .gesture(drag.exclusively(before: TapGesture().onEnded { onSelect() }))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(decoration.name)
            .accessibilityValue(placement.isLocked ? "Locked in place" : "Movable")
            .accessibilityHint("Drag to position. Double-tap to show lock controls.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSelect() }
            .accessibilityAction(named: placement.isLocked ? "Unlock" : "Lock in place") { toggleLock() }
            .overlay(alignment: .top) {
                if isSelected && dragOrigin == nil {
                    Button(action: toggleLock) {
                        Label(placement.isLocked ? "Unlock" : "Lock", systemImage: placement.isLocked ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .pixelPanel(Palette.paper, shadow: false)
                    }.buttonStyle(.plain).fixedSize().offset(y: -50)
                        .accessibilityLabel("\(placement.isLocked ? "Unlock" : "Lock") \(decoration.name)")
                }
            }
            .overlay(alignment: .bottom) {
                if showLabel || isSelected {
                    Text(placement.isLocked ? "Locked" : decoration.name)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(4).background(Palette.paper, in: PixelFrame()).fixedSize().offset(y: 20)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .position(center)
            .zIndex(dragOrigin != nil ? 200 : (isSelected ? 90 : 2))
            .onChange(of: gestureActive) { _, active in if !active { finishDrag() } }
            .onChange(of: placement) { _, _ in cancelDrag() }
            .onChange(of: playground) { _, _ in cancelDrag() }
            .onChange(of: size) { _, _ in cancelDrag() }
            .onChange(of: sceneActive) { _, active in if !active { cancelDrag() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { cancelDrag() } }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("habitatWorld"))
            .updating($gestureActive) { _, active, _ in active = true }
            .onChanged { value in
                guard !placement.isLocked else { onSelect(); return }
                if dragOrigin == nil {
                    dragOrigin = basePosition
                    onSelect()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                }
                translation = value.translation
            }
            .onEnded { _ in finishDrag() }
    }

    private func finishDrag() {
        guard dragOrigin != nil else { return }
        let point = center
        if !placement.isLocked && playground.width > 0 && playground.height > 0 {
            onMove(Double((point.x - playground.minX) / playground.width),
                   Double((point.y - playground.minY) / playground.height))
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        }
        cancelDrag()
    }

    private func cancelDrag() { dragOrigin = nil; translation = .zero }

    private func toggleLock() {
        cancelDrag()
        onLock(!placement.isLocked)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }
}
