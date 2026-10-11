import SwiftUI
import UIKit

@main
struct EcoGotchiApp: App {
    @StateObject private var store = HabitatStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Palette.forest)
                .fontDesign(.monospaced)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refresh() }
                }
        }
    }
}

enum Palette {
    static let cream = Color(red: 0.95, green: 0.94, blue: 0.85)
    static let forest = Color(red: 0.14, green: 0.25, blue: 0.20)
    static let sage = Color(red: 0.81, green: 0.87, blue: 0.66)
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.39)
    static let paper = Color(red: 1.0, green: 0.99, blue: 0.92)
    static let coral = Color(red: 0.88, green: 0.48, blue: 0.34)
}

// Stepped corners and an offset shadow echo a tiny handheld game's UI.
struct PixelFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let s: CGFloat = min(6, min(rect.width, rect.height) / 4)
        var path = Path()
        path.move(to: CGPoint(x: s, y: 0))
        for point in [CGPoint(x: rect.width - s, y: 0), CGPoint(x: rect.width - s, y: s),
                      CGPoint(x: rect.width, y: s), CGPoint(x: rect.width, y: rect.height - s),
                      CGPoint(x: rect.width - s, y: rect.height - s), CGPoint(x: rect.width - s, y: rect.height),
                      CGPoint(x: s, y: rect.height), CGPoint(x: s, y: rect.height - s),
                      CGPoint(x: 0, y: rect.height - s), CGPoint(x: 0, y: s), CGPoint(x: s, y: s)] {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

extension View {
    func pixelPanel(_ fill: Color = Palette.paper, shadow: Bool = true) -> some View {
        self.background(fill)
            .clipShape(PixelFrame())
            .overlay(PixelFrame().stroke(Palette.forest, lineWidth: 2))
            .background(PixelFrame().fill(Palette.forest.opacity(shadow ? 0.22 : 0)).offset(x: 3, y: 4))
    }
}

struct PixelButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var secondary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .monospaced, weight: .bold))
            .padding(.horizontal, 16).padding(.vertical, 14)
            .foregroundStyle(secondary ? Palette.forest : Palette.paper)
            .pixelPanel(secondary ? Palette.sage : Palette.forest, shadow: !configuration.isPressed)
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 3 : 0)
            .opacity(enabled ? 1 : 0.45)
    }
}

struct PixelWordmark: View {
    // Original 5x7 lettering, drawn as square cells so the title stays crisp.
    private let glyphs: [Character: [String]] = [
        "E": ["11111","10000","10000","11110","10000","10000","11111"],
        "C": ["01111","10000","10000","10000","10000","10000","01111"],
        "O": ["01110","10001","10001","10001","10001","10001","01110"],
        "G": ["01111","10000","10000","10111","10001","10001","01110"],
        "T": ["11111","00100","00100","00100","00100","00100","00100"],
        "H": ["10001","10001","10001","11111","10001","10001","10001"],
        "I": ["11111","00100","00100","00100","00100","00100","11111"]
    ]
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width / 53, size.height / 7)
            for (index, letter) in "ECOGOTCHI".enumerated() {
                for (row, line) in (glyphs[letter] ?? []).enumerated() {
                    for (column, pixel) in line.enumerated() where pixel == "1" {
                        let rect = CGRect(x: CGFloat(index * 6 + column) * unit, y: CGFloat(row) * unit, width: unit, height: unit)
                        context.fill(Path(rect), with: .color(Palette.forest))
                    }
                }
            }
        }.frame(width: 212, height: 28).accessibilityLabel("EcoGotchi")
    }
}

enum GameSprite: String, CaseIterable {
    case pip, fern, clover, maple, flowers, mushrooms, house, leaf, bottle, can, cup, paper
    case bubbles, shelly, inky, fin, waddles, flurry, pebble, snowdrop
    case berries, kelp, crunch, apple
    case bench, lantern, fernPlant, coral, pearl, sandcastle, igloo, snowman, spruce

    private var atlas: (name: String, bounds: CGRect) {
        let friends: [GameSprite] = [.bubbles, .shelly, .inky, .fin, .waddles, .flurry, .pebble, .snowdrop, .berries, .kelp, .crunch, .apple]
        let decor: [GameSprite] = [.bench, .lantern, .fernPlant, .coral, .pearl, .sandcastle, .igloo, .snowman, .spruce]
        if let index = friends.firstIndex(of: self) {
            return ("FriendsAndFood", CGRect(x: CGFloat(index % 4) / 4, y: CGFloat(index / 4) / 3, width: 0.25, height: 1.0 / 3))
        }
        if let index = decor.firstIndex(of: self) {
            return ("HabitatDecor", CGRect(x: CGFloat(index % 3) / 3, y: CGFloat(index / 3) / 3, width: 1.0 / 3, height: 1.0 / 3))
        }
        return ("EcoSpritesPixel", bounds)
    }

    // Atlas artwork has hand-spaced rows, so use content bounds rather than a uniform grid.
    var bounds: CGRect {
        let index = Self.allCases.firstIndex(of: self)!
        let x: [CGFloat] = [40, 345, 638, 925]
        let widths: [CGFloat] = [272, 287, 289, 310]
        let y: [CGFloat] = [165, 520, 873]
        let heights: [CGFloat] = [333, 293, 273]
        return CGRect(x: x[index % 4] / 1254, y: y[index / 4] / 1254,
                      width: widths[index % 4] / 1254, height: heights[index / 4] / 1254)
    }

    static let images: [GameSprite: UIImage] = {
        let atlases = ["EcoSpritesPixel", "FriendsAndFood", "HabitatDecor"].reduce(into: [String: CGImage]()) { result, name in
            result[name] = UIImage(named: name)?.cgImage
        }
        return Dictionary(uniqueKeysWithValues: allCases.compactMap { sprite in
            let source = sprite.atlas
            guard let atlas = atlases[source.name] else { return nil }
            let b = source.bounds
            let crop = CGRect(x: b.minX * CGFloat(atlas.width), y: b.minY * CGFloat(atlas.height),
                              width: b.width * CGFloat(atlas.width), height: b.height * CGFloat(atlas.height)).integral
            guard let image = atlas.cropping(to: crop) else { return nil }
            return (sprite, UIImage(cgImage: image))
        })
    }()
}

struct PixelSprite: View {
    private static let expressions: [GameSprite: [HabitatCondition: UIImage]] = {
        var result: [GameSprite: [HabitatCondition: UIImage]] = [:]
        for animal in HabitatAnimal.all {
            guard let sprite = GameSprite(rawValue: animal.id) else { continue }
            for condition in HabitatCondition.allCases {
                guard let frame = AnimalExpressions.frame(animalID: animal.id, condition: condition),
                      let atlas = UIImage(named: frame.asset)?.cgImage else { continue }
                let b = frame.rect
                let crop = CGRect(x:b.minX * CGFloat(atlas.width), y:b.minY * CGFloat(atlas.height),
                    width:b.width * CGFloat(atlas.width), height:b.height * CGFloat(atlas.height)).integral
                if let image = atlas.cropping(to: crop) {
                    result[sprite, default: [:]][condition] = UIImage(cgImage: image)
                }
            }
        }
        return result
    }()

    let sprite: GameSprite
    var size: CGFloat = 48
    var condition: HabitatCondition?

    var body: some View {
        Group {
            if let image = condition.flatMap({ Self.expressions[sprite]?[$0] }) ?? GameSprite.images[sprite] {
                Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
            } else {
                Image(systemName: "leaf.fill").resizable().scaledToFit()
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}
