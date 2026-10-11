import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var store: HabitatStore
    @StateObject private var recyclingFinder = RecyclingFinder()
    @State private var panel: HabitatPanel?
    @State private var shopSection = ShopSection.food
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            HabitatScene(state: store.state, options: store.developer, sceneActive: panel == nil)
                .id("\(store.state.habitat.rawValue)-\(store.modeSessionID)")
                .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar
                status
                Spacer(minLength: 12)
                actionDock
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .foregroundStyle(Palette.forest)
        .sheet(item: $panel) { destination in
            switch destination {
            case .camera:
                RecyclingView(launchCameraOnOpen: true)
            case .friends:
                HabitatOverlay(title: "Friends", subtitle: store.state.habitat.title) { CollectionView() }
            case .shop:
                HabitatOverlay(title: "Shop", subtitle: "Treats, treasures & new places") { ShopView(section: shopSection) }
            case .journal:
                HabitatOverlay(title: "Journal", subtitle: "Your little acts of care") { ActivityView() }
            case .bins:
                RecyclingMapView(finder: recyclingFinder)
            case .developer:
                DeveloperPanel()
            }
        }
        .onReceive(timer) { _ in store.refresh() }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { openShop() } label: {
                HStack(spacing: 6) {
                    PixelSprite(sprite: .leaf, size: 24)
                    Text("\(store.state.points)").font(.system(.subheadline, design: .monospaced, weight: .heavy))
                }.padding(.horizontal, 12).frame(minHeight: 52)
                    .pixelPanel(Palette.paper.opacity(0.96), shadow: false)
            }.buttonStyle(.plain)
                .accessibilityLabel("\(store.state.points) leaves. Open shop")

            Spacer(minLength: 0)
            shortcut("Find a bin", symbol: "map.fill") { panel = .bins }
            shortcut("Journal", symbol: "book.closed.fill") { panel = .journal }
            shortcut(store.isDeveloperMode ? "Dev: on" : "Dev", symbol: "slider.horizontal.3",
                     highlighted: store.isDeveloperMode) {
                store.beginDeveloperMode()
                panel = .developer
            }
        }
    }

    private func shortcut(_ title: String, symbol: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
                .padding(.horizontal, 10)
                .frame(minWidth: 60, minHeight: 52)
                .pixelPanel(highlighted ? Palette.gold : Palette.paper.opacity(0.96), shadow: false)
        }.buttonStyle(.plain)
            .accessibilityLabel(title == "Dev" || highlighted ? "Developer controls" : title)
    }

    private var status: some View {
        VStack(spacing: 8) {
            Button { openShop(.habitats) } label: {
                HStack(spacing: 6) {
                    Text(store.state.habitat.title.uppercased()).tracking(1)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }.font(.system(size: 12, weight: .heavy, design: .monospaced)).frame(minHeight: 32)
            }.buttonStyle(.plain).accessibilityLabel("Change habitat. Current: \(store.state.habitat.title)")
            HStack(spacing: 7) {
                Rectangle().fill(conditionColor).frame(width: 7, height: 7)
                Text(store.state.condition.title.uppercased()).font(.system(size: 10, weight: .bold))
                Text("· \(store.state.litter)/6 litter").font(.system(size: 10))
            }
            HStack(spacing: 3) {
                ForEach(0..<10) { index in
                    Rectangle().fill(index * 10 < store.state.health ? conditionColor : Palette.forest.opacity(0.14))
                        .frame(width: 12, height: 5)
                }
            }.accessibilityLabel("Habitat health \(store.state.health) percent")
        }.padding(.horizontal, 18).padding(.vertical, 12)
            .pixelPanel(Palette.paper.opacity(0.9), shadow: false)
    }

    private var conditionColor: Color {
        switch store.state.condition {
        case .thriving, .littered: Palette.forest
        case .tarnished: Color(red: 0.55, green: 0.39, blue: 0.14)
        case .polluted: Palette.coral
        }
    }

    private var actionDock: some View {
        VStack(spacing: 12) {
            if let food = store.selectedFood {
                HStack(spacing: 8) {
                    PixelSprite(sprite: GameSprite(rawValue: food.id) ?? .apple, size: 28)
                    Text("Tap a pet to feed · \(store.state.foodCount(food.id)) left")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    Button { store.selectFood(nil) } label: {
                        Image(systemName: "xmark").font(.caption.bold()).frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Stop feeding")
                }.padding(.leading, 10).pixelPanel(Palette.paper, shadow: false)
            } else if store.isDeveloperMode {
                Text("Preview mode · changes are temporary")
                    .font(.caption2).padding(8)
                    .background(Palette.gold, in: PixelFrame())
            } else {
                Text("Tap to pet · drag to play")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.paper.opacity(0.9), in: PixelFrame())
                    .allowsHitTesting(false)
            }
            HStack(alignment: .center, spacing: 12) {
                dockButton("Friends", sprite: GameSprite(rawValue: store.state.habitat.starterID) ?? .pip) { panel = .friends }
                Button { panel = .camera } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill").font(.system(size: 29, weight: .bold))
                        Text("RECYCLE").font(.system(size: 11, weight: .heavy)).tracking(1)
                    }.frame(width: 76, height: 68)
                }.buttonStyle(PixelButtonStyle())
                    .accessibilityLabel("Recycle. Open camera")
                dockButton("Shop", sprite: .apple) { openShop() }
            }
        }.frame(maxWidth: .infinity)
    }

    private func openShop(_ section: ShopSection = .food) {
        shopSection = section
        panel = .shop
    }

    private func dockButton(_ title: String, sprite: GameSprite, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                PixelSprite(sprite: sprite, size: 34)
                Text(title).font(.system(size: 11, weight: .bold))
            }.frame(maxWidth: .infinity).frame(height: 76)
                .pixelPanel(Palette.paper.opacity(0.96))
        }.buttonStyle(.plain)
    }

}

private enum HabitatPanel: String, Identifiable {
    case camera, friends, shop, journal, developer, bins
    var id: String { rawValue }
}

struct HabitatOverlay<Content: View>: View {
    let title: String
    var subtitle: String = ""
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold())
                    if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44).background(Palette.sage, in: PixelFrame())
                }.buttonStyle(.plain).accessibilityLabel("Close \(title) and return to habitat")
            }.padding(20)
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.cream).foregroundStyle(Palette.forest)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(560), .large])
        .presentationDragIndicator(.visible)
    }
}
