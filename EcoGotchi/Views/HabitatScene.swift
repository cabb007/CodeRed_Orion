import SwiftUI

struct HabitatScene: View {
    let state: HabitatState
    var options = DeveloperOptions()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            // Background and sprites share one coordinate plane, including on tall iPhones.
            let width = max(geo.size.width, geo.size.height * 9 / 16)
            let height = max(geo.size.height, geo.size.width * 16 / 9)
            TimelineView(.animation(minimumInterval: 0.7, paused: reduceMotion || !options.animateAnimals)) { timeline in
                let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.7) % 2
                world(width: width, height: height, tick: tick)
                    .frame(width: width, height: height)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: state.condition)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: state.litter)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Willow Grove, \(state.condition.title). Health \(state.health) percent. \(state.litter) pieces of litter. \(state.residentAnimals.count) animals in the habitat.")
    }

    private func world(width: CGFloat, height: CGFloat, tick: Int) -> some View {
        ZStack {
            Image(state.condition.assetName).resizable().interpolation(.none)
                .frame(width: width, height: height)
                .saturation(state.condition == .littered ? 0.84 : 1)
                .id(state.condition.assetName)
                .transition(.opacity)

            if options.showAtmosphere {
                atmosphere(width: width, height: height, tick: tick)
            }

            if state.ownedDecorations.contains("house") {
                sprite(.house, label: "Hideaway", size: width * 0.20)
                    .position(x: width * 0.21, y: height * 0.51)
            }
            if state.ownedDecorations.contains("flowers") {
                sprite(.flowers, label: "Wildflowers", size: width * 0.14)
                    .position(x: width * 0.16, y: height * 0.73)
            }
            if state.ownedDecorations.contains("mushrooms") {
                sprite(.mushrooms, label: "Mushrooms", size: width * 0.13)
                    .position(x: width * 0.86, y: height * 0.66)
            }

            ForEach(Array(HabitatAnimal.all.enumerated()), id: \.element.id) { index, animal in
                if isVisible(animal) {
                    sprite(GameSprite(rawValue: animal.id) ?? .pip, label: animal.name, size: width * 0.15)
                        .offset(y: reduceMotion || !options.animateAnimals ? 0 : ((tick + index) % 2 == 0 ? 0 : -3))
                        .position(x: width * [0.34, 0.65, 0.60, 0.27][index],
                                  y: height * [0.60, 0.57, 0.71, 0.74][index])
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
        }
    }

    private func isVisible(_ animal: HabitatAnimal) -> Bool {
        let unlocked = state.unlockedAnimals.contains { $0.id == animal.id }
        let present = options.ignoreRetreat || state.condition != .polluted || animal.id == "pip"
        return unlocked && present && !options.hiddenAnimals.contains(animal.id)
    }

    private func sprite(_ kind: GameSprite, label: String, size: CGFloat) -> some View {
        PixelSprite(sprite: kind, size: size * options.spriteScale)
            .overlay(alignment: .bottom) {
                if options.showLabels {
                    Text(label).font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(3).background(Palette.paper).fixedSize().offset(y: 12)
                }
            }
    }

    private func atmosphere(width: CGFloat, height: CGFloat, tick: Int) -> some View {
        ZStack {
            if state.condition == .thriving {
                ForEach(0..<6) { index in
                    Rectangle().fill(Palette.paper.opacity(tick == index % 2 ? 0.8 : 0.25))
                        .frame(width: 3, height: 3)
                        .position(x: width * [0.30, 0.75, 0.47, 0.61, 0.23, 0.82][index],
                                  y: height * [0.47, 0.64, 0.72, 0.50, 0.66, 0.44][index])
                }
            } else if state.condition == .polluted {
                ForEach(0..<3) { index in
                    Rectangle().fill(Color.gray.opacity(0.09))
                        .frame(width: width * 0.7, height: height * 0.04)
                        .position(x: width * (index % 2 == 0 ? 0.4 : 0.6), y: height * (0.33 + Double(index) * 0.12))
                }
            }
        }.allowsHitTesting(false)
    }
}
