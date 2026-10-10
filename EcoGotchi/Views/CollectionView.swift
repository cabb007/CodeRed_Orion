import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("\(store.state.unlockedAnimals.count) of \(HabitatAnimal.all.count) friends")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "pawprint.fill")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(HabitatAnimal.all) { animal in
                        friendCard(animal)
                    }
                }
                if let next = store.state.nextAnimal {
                    Text("\(next.requiredActions - store.state.actions.count) more actions to meet \(next.name).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
    }

    private func friendCard(_ animal: HabitatAnimal) -> some View {
        let unlocked = store.state.actions.count >= animal.requiredActions
        return VStack(spacing: 8) {
            PixelSprite(sprite: GameSprite(rawValue: animal.id) ?? .pip, size: 66)
                .saturation(unlocked ? 1 : 0).opacity(unlocked ? 1 : 0.35)
            Text(animal.name).font(.headline)
            Label(unlocked ? "Collected" : "\(animal.requiredActions) actions", systemImage: unlocked ? "checkmark" : "lock.fill")
                .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(unlocked ? Palette.sage.opacity(0.65) : Palette.paper, in: PixelFrame())
            .accessibilityElement(children: .combine)
            .accessibilityHint(animal.detail)
    }
}

struct ShopView: View {
    @EnvironmentObject private var store: HabitatStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    PixelSprite(sprite: .leaf, size: 26)
                    Text("\(store.state.points) leaves").font(.headline)
                    Spacer()
                }
                VStack(spacing: 0) {
                    ForEach(Decoration.all) { item in
                        shopRow(item)
                        if item.id != Decoration.all.last?.id { Divider().padding(.horizontal, 14) }
                    }
                }.background(Palette.paper, in: PixelFrame())
                Text("Recycling earns leaves. Decorations appear in your habitat as soon as you add them.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
    }

    private func shopRow(_ item: Decoration) -> some View {
        let owned = store.state.ownedDecorations.contains(item.id)
        let canAfford = store.state.points >= item.cost
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                itemInfo(item, owned: owned, canAfford: canAfford)
                Spacer(minLength: 4)
                buyButton(item, owned: owned, canAfford: canAfford)
            }
            VStack(alignment: .leading, spacing: 12) {
                itemInfo(item, owned: owned, canAfford: canAfford)
                buyButton(item, owned: owned, canAfford: canAfford)
            }
        }.padding(14)
    }

    private func itemInfo(_ item: Decoration, owned: Bool, canAfford: Bool) -> some View {
        HStack(spacing: 12) {
            PixelSprite(sprite: GameSprite(rawValue: item.id) ?? .leaf, size: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
                Text(owned ? "In your habitat" : "\(item.cost) leaves")
                    .font(.caption).foregroundStyle(.secondary)
                if !owned && !canAfford {
                    Text("\(item.cost - store.state.points) more to go").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func buyButton(_ item: Decoration, owned: Bool, canAfford: Bool) -> some View {
        Button { store.buy(item) } label: {
            if owned { Image(systemName: "checkmark").frame(minWidth: 28) }
            else { Text("Add").frame(minWidth: 28) }
        }.buttonStyle(PixelButtonStyle(secondary: owned))
            .disabled(owned || !canAfford)
            .accessibilityLabel(owned ? "\(item.name), already owned" : "Add \(item.name) for \(item.cost) leaves")
    }
}

struct ActivityView: View {
    @EnvironmentObject private var store: HabitatStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(store.state.actions.count) actions logged").font(.headline)
                if store.state.actions.isEmpty {
                    VStack(spacing: 12) {
                        PixelSprite(sprite: .leaf, size: 64)
                        Text("Your first small step awaits.").font(.subheadline.bold())
                        Text("Tap Recycle in your habitat to begin.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 36)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(store.state.actions.reversed()) { action in
                            HStack(spacing: 12) {
                                PixelSprite(sprite: .leaf, size: 28)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(action.item).font(.subheadline.bold())
                                    Text(action.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(action.isDemo ? "Demo · automatically accepted" : (action.verificationID != nil ? "AI-reviewed · \(action.material?.capitalized ?? "Recycling")" : (action.item.hasPrefix("[Preview]") ? "Developer preview" : "Previously self-reported")))
                                        .font(.caption2).foregroundStyle(.secondary)
                                    if let tip = action.recyclingTip {
                                        Text(tip).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                Text("+\(action.reward)").font(.subheadline.bold()).monospacedDigit()
                                    .accessibilityLabel("\(action.reward) leaves earned")
                            }.padding(.vertical, 14)
                            Divider()
                        }
                    }
                }
                Text(store.isDeveloperMode ? "Preview actions are temporary." : (store.isDemoRecycling ? "Demo scans earn 20 leaves automatically. They are not AI-verified." : "AI reviews assess visible evidence, not downstream recycling. Demo entries are labeled separately."))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
    }
}
