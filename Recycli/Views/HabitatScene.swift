import SwiftUI

struct HabitatScene: View {
    let state: HabitatState
    var options = DeveloperOptions()
    var sceneActive = true
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var animalWorld = AnimalWorld()
    @State private var selectedDecoration: String?

    var body: some View {
        GeometryReader { geo in
            // Background and sprites share one coordinate plane, including on tall iPhones.
            let width = max(geo.size.width, geo.size.height * 9 / 16)
            let height = max(geo.size.height, geo.size.width * 16 / 9)
            let visible = CGRect(x: (width - geo.size.width) / 2, y: (height - geo.size.height) / 2,
                                 width: geo.size.width, height: geo.size.height)
            // Leave room for the habitat header and the food prompt above the bottom dock.
            let playTop = visible.minY + max(visible.height * 0.30, min(220, visible.height * 0.40))
            let playBottom = visible.maxY - min(205, visible.height * 0.40)
            let playground = CGRect(x: visible.minX + 10, y: playTop,
                                    width: max(0, visible.width - 20), height: max(0, playBottom - playTop))
            world(width: width, height: height, playground: playground)
                .frame(width: width, height: height)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: state.condition)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: state.litter)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(state.habitat.title), \(state.condition.title). Health \(state.health) percent. \(state.litter) pieces of litter. \(state.residentAnimals.count) animals in the habitat.")
    }

    private func world(width: CGFloat, height: CGFloat, playground: CGRect) -> some View {
        ZStack {
            HabitatArtwork(asset: state.habitat.asset(for: state.condition))
                .frame(width: width, height: height)
                .saturation(backgroundSaturation)
                .id(state.habitat.asset(for: state.condition))
                .transition(.opacity)
                .allowsHitTesting(false).accessibilityHidden(true)

            if options.showAtmosphere {
                HabitatAtmosphere(habitat: state.habitat, condition: state.condition, litter: state.litter,
                                  animate: options.animateHabitat, sceneActive: sceneActive)
                    .frame(width: width, height: height)
            }

            ForEach(state.habitat.decorations) { decoration in
                if state.ownedDecorations.contains(decoration.id) {
                    InteractiveDecoration(decoration: decoration,
                        home: CGPoint(x: width * decoration.x, y: height * decoration.y),
                        playground: playground, size: width * decoration.scale * options.spriteScale,
                        placement: state.placement(for: decoration.id), isSelected: selectedDecoration == decoration.id,
                        showLabel: options.showLabels, sceneActive: sceneActive,
                        onSelect: { selectedDecoration = decoration.id },
                        onMove: { x, y in store.moveDecoration(decoration.id, x: x, y: y) },
                        onLock: { store.setDecorationLocked(decoration.id, locked: $0) })
                }
            }

            ForEach(Array(visibleAnimals.enumerated()), id: \.element.id) { index, animal in
                if isVisible(animal) {
                    InteractivePet(world: animalWorld, animal: animal,
                                   home: CGPoint(x: width * [0.34, 0.65, 0.60, 0.27][index],
                                                 y: height * (state.habitat == .ocean ? [0.52, 0.60, 0.67, 0.56][index] : [0.68, 0.65, 0.73, 0.70][index])),
                                   playground: playground, size: min(width * 0.15 * options.spriteScale, max(1, (playground.width - 16) / CGFloat(max(1, visibleAnimals.count)) / 1.8)),
                                   roamEnabled: options.animateAnimals, sceneActive: sceneActive,
                                   showLabel: options.showLabels)
                        .transition(.opacity)
                }
            }

            ForEach(0..<state.litter, id: \.self) { index in
                sprite([.cup, .can, .bottle, .paper, .bottle, .cup][index], label: "Litter \(index + 1)", size: width * 0.085)
                    .position(x: width * [0.43, 0.73, 0.23, 0.56, 0.79, 0.41][index],
                              y: height * [0.72, 0.65, 0.63, 0.61, 0.54, 0.53][index])
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if options.showGrid {
                Canvas { context, size in
                    var path = Path()
                    for index in 1..<10 {
                        let fraction = CGFloat(index) / 10
                        path.move(to: CGPoint(x: size.width * fraction, y: 0))
                        path.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
                        path.move(to: CGPoint(x: 0, y: size.height * fraction))
                        path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }.allowsHitTesting(false)
            }
        }.background {
            Color.clear.contentShape(Rectangle()).onTapGesture { selectedDecoration = nil }
        }.coordinateSpace(name: "habitatWorld")
            .onChange(of: sceneActive) { _, active in if !active { selectedDecoration = nil } }
            .onChange(of: store.isDeveloperMode) { _, _ in selectedDecoration = nil }
    }

    private var visibleAnimals: [HabitatAnimal] {
        Array(state.habitat.animals.filter { isVisible($0) }.prefix(AnimalWorld.capacity))
    }

    private func isVisible(_ animal: HabitatAnimal) -> Bool {
        let unlocked = state.unlockedAnimals.contains { $0.id == animal.id }
        let present = options.ignoreRetreat || state.condition != .polluted || animal.requiredActions == 0
        return unlocked && present && !options.hiddenAnimals.contains(animal.id)
    }

    private func sprite(_ kind: GameSprite, label: String, size: CGFloat) -> some View {
        PixelSprite(sprite: kind, size: size * options.spriteScale)
            .allowsHitTesting(false)
            .overlay(alignment: .bottom) {
                if options.showLabels {
                    Text(label).font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(3).background(Palette.paper).fixedSize().offset(y: 12)
                }
            }
    }

    private var backgroundSaturation: Double {
        // Ocean and snow have dedicated artwork for every condition.
        state.habitat == .grove && state.condition == .littered ? 0.84 : 1
    }

}
