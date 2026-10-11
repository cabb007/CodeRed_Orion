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
                .id(store.state.habitat)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar
                HabitatStatusControls(state: store.state, selectHabitat: store.selectHabitat)
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

    private var actionDock: some View {
        VStack(spacing: 12) {
            if let review = store.scanReview {
                Button { panel = .camera } label: {
                    HStack(spacing: 10) {
                        if review.status == .reviewing { ProgressView().tint(Palette.forest) }
                        else { Image(systemName: review.leaves > 0 ? "leaf.fill" : "info.circle") }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(review.title).font(.system(size: 12, weight: .bold, design: .monospaced))
                            Text("\(review.habitat.title) · tap for details").font(.system(size: 10))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.bold())
                    }.padding(12).frame(maxWidth: .infinity, minHeight: 44)
                        .pixelPanel(Palette.paper)
                }.buttonStyle(.plain)
            }
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
                        Text(store.isDeveloperMode ? (store.isDemoRecycling ? "+\(store.developer.actionReward) preview" : "Actual · preview") : (store.isDemoRecycling ? "Demo · +20 leaves" : "Actual AI review"))
                            .font(.system(size: 9, weight: .medium)).opacity(0.8)
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

private struct HabitatStatusControls: View {
    let state: HabitatState
    let selectHabitat: (HabitatKind) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            arrow(destination: state.habitat.previous, pointsLeft: true)
            VStack(spacing: 8) {
                Menu {
                    ForEach(HabitatKind.allCases) { habitat in
                        Button { selectHabitat(habitat) } label: {
                            if habitat == state.habitat {
                                Label(habitat.title, systemImage: "checkmark")
                            } else { Text(habitat.title) }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(state.habitat.title.uppercased()).tracking(0.6)
                            .lineLimit(1).minimumScaleFactor(0.75)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .heavy))
                    }
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel("Change habitat. Current: \(state.habitat.title)")

                HStack(spacing: 4) {
                    Text(state.condition.title.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 2)
                    Text("\(state.cleanedPercent)% cleaned")
                        .font(.system(size: 10, weight: .medium, design: .monospaced)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Palette.forest.opacity(0.14))
                        Rectangle().fill(conditionColor)
                            .frame(width: geometry.size.width * state.cleanedFraction)
                    }
                }
                .frame(height: 9)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: state.cleanedFraction)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Habitat cleaned")
                .accessibilityValue("\(state.cleanedPercent) percent")
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .pixelPanel(Palette.paper.opacity(0.94), shadow: false)
            arrow(destination: state.habitat.next, pointsLeft: false)
        }
    }

    @ViewBuilder
    private func arrow(destination: HabitatKind?, pointsLeft: Bool) -> some View {
        if let destination {
            Button { selectHabitat(destination) } label: {
                PixelHabitatArrow().fill(Palette.forest)
                    .frame(width: 28, height: 28)
                    .scaleEffect(x: pointsLeft ? -1 : 1, y: 1)
                    .frame(width: 44, height: 52)
                    .pixelPanel(Palette.paper.opacity(0.96))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(pointsLeft ? "Previous" : "Next") habitat: \(destination.title)")
        } else {
            // Reserve the slot so the menu doesn't jump when an end is reached.
            Color.clear.frame(width: 44, height: 52).allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private var conditionColor: Color {
        switch state.condition {
        case .thriving, .littered: Palette.forest
        case .tarnished: Color(red: 0.55, green: 0.39, blue: 0.14)
        case .polluted: Palette.coral
        }
    }
}

private struct PixelHabitatArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let rows = ["0001000", "0001100", "1111110", "1111111", "1111110", "0001100", "0001000"]
        var path = Path()
        for (y, row) in rows.enumerated() {
            for (x, cell) in row.enumerated() where cell == "1" {
                path.addRect(CGRect(x: rect.minX + CGFloat(x) * rect.width / 7,
                                    y: rect.minY + CGFloat(y) * rect.height / 7,
                                    width: rect.width / 7, height: rect.height / 7))
            }
        }
        return path
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
