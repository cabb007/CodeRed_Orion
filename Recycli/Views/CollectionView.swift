import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("\(store.state.unlockedAnimals.count) of \(store.state.habitat.animals.count) friends")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "pawprint.fill")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(store.state.habitat.animals) { animal in
                        friendCard(animal)
                    }
                }
                Text("Recycle in \(store.state.habitat.title) to welcome its friends.")
                    .font(.caption).foregroundStyle(.secondary)
                if let next = store.state.nextAnimal {
                    Text("\(next.requiredActions - store.state.habitatActionCount) more actions to meet \(next.name).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
    }

    private func friendCard(_ animal: HabitatAnimal) -> some View {
        let unlocked = store.state.habitatActionCount >= animal.requiredActions
        return VStack(spacing: 8) {
            PixelSprite(sprite: GameSprite(rawValue: animal.id) ?? .pip, size: 66, condition: store.state.condition)
                .saturation(unlocked ? 1 : 0).opacity(unlocked ? 1 : 0.35)
            Text(animal.name).font(.headline)
            Label(unlocked ? "Collected" : "\(animal.requiredActions) actions", systemImage: unlocked ? "checkmark" : "lock.fill")
                .font(.caption).foregroundStyle(.secondary)
            if unlocked, let meals = store.state.petMeals?[animal.id], meals > 0 {
                Text("Fed \(meals) \(meals == 1 ? "time" : "times")").font(.caption2).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(unlocked ? Palette.sage.opacity(0.65) : Palette.paper, in: PixelFrame())
            .accessibilityElement(children: .combine)
            .accessibilityHint(animal.detail)
    }
}

enum ShopSection: String, CaseIterable, Identifiable {
    case food = "Food", decorations = "Decorations", habitats = "Habitats", leaves = "Buy Leaves"
    var id: String { rawValue }
}

struct ShopView: View {
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.dismiss) private var dismiss
    @State private var section: ShopSection
    @State private var notice: String?

    init(section: ShopSection = .food) { _section = State(initialValue: section) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                PixelSprite(sprite: .leaf, size: 26)
                Text("\(store.state.points) leaves").font(.headline)
                Spacer()
                Text(store.state.habitat.title).font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20)
            Picker("Shop section", selection: $section) {
                ForEach(ShopSection.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if section == .food { foodShelf }
                    if section == .decorations { decorationShelf }
                    if section == .habitats { habitatShelf }
                    if section == .leaves { LeafShopView() }
                }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
            }
        }.onChange(of: section) { _, _ in notice = nil }
    }

    private var foodShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Buy a snack, choose Use, then tap a pet in your habitat to feed it.")
                .font(.caption).foregroundStyle(.secondary)
            if let notice {
                Label(notice, systemImage: "checkmark.circle.fill").font(.caption.bold())
            }
            ForEach(store.state.habitat.foods) { food in
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        PixelSprite(sprite: GameSprite(rawValue: food.id) ?? .apple, size: 58)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(food.name).font(.subheadline.bold())
                            Text(food.detail).font(.caption).foregroundStyle(.secondary)
                            Text("\(food.cost) leaves · \(store.state.foodCount(food.id)) in bag")
                                .font(.caption.bold())
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 12) {
                        Button {
                            if store.buyFood(food.id) {
                                notice = "\(food.name) added to your bag."
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                            }
                        } label: { Text("Buy · \(food.cost)").frame(maxWidth: .infinity) }
                            .buttonStyle(PixelButtonStyle())
                            .disabled(store.state.points < food.cost || store.state.foodCount(food.id) >= 99)
                            .accessibilityLabel("Buy one \(food.name) for \(food.cost) leaves")
                        Button {
                            store.selectFood(food.id)
                            dismiss()
                        } label: { Text("Use").frame(maxWidth: .infinity) }
                            .buttonStyle(PixelButtonStyle(secondary: true))
                            .disabled(store.state.foodCount(food.id) == 0)
                            .accessibilityLabel("Use \(food.name). Then tap a pet to feed it")
                    }
                }.padding(14).background(Palette.paper, in: PixelFrame())
            }
            Text("Treats make your virtual pets happy. Each feeding uses one snack; recycling restores the habitat and earns leaves.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var decorationShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Little touches for \(store.state.habitat.title).")
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(store.state.habitat.decorations) { item in
                    decorationRow(item)
                    if item.id != store.state.habitat.decorations.last?.id { Divider().padding(.horizontal, 14) }
                }
            }.background(Palette.paper, in: PixelFrame())
            Text("Drag decorations around your habitat. Tap one to lock it in place, or lock and unlock it here. Your layout saves automatically.")
                .font(.caption).foregroundStyle(.secondary)
            if store.state.habitat.decorations.contains(where: { store.state.ownedDecorations.contains($0.id) }) {
                Button("Reset this habitat’s positions & locks") { store.resetDecorationLayout() }
                    .font(.caption.bold()).frame(minHeight: 44)
            }
        }
    }

    private var habitatShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Three homes, one little world. Each has its own friends and cleanup progress. All habitats are free to visit.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(HabitatKind.allCases) { habitat in
                Button {
                    store.selectHabitat(habitat)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        HabitatArtwork(asset: habitat.cleanAsset).scaledToFill()
                            .frame(width: 80, height: 100).clipped().clipShape(PixelFrame())
                            .overlay { PixelSprite(sprite: GameSprite(rawValue: habitat.starterID) ?? .pip, size: 46).offset(y: 15) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(habitat.title).font(.headline)
                            Text(habitat.detail).font(.caption).foregroundStyle(.secondary)
                            Label(store.state.habitat == habitat ? "You’re here" : "Visit habitat",
                                  systemImage: store.state.habitat == habitat ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                .font(.caption.bold())
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(12).background(Palette.paper, in: PixelFrame())
                }.buttonStyle(.plain).accessibilityLabel("\(habitat.title). \(store.state.habitat == habitat ? "Current habitat" : "Visit for free")")
            }
        }
    }

    private func decorationRow(_ item: Decoration) -> some View {
        let owned = store.state.ownedDecorations.contains(item.id)
        let canAfford = store.state.points >= item.cost
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                itemInfo(item, owned: owned, canAfford: canAfford)
                Spacer(minLength: 4)
                decorationButton(item, owned: owned, canAfford: canAfford)
            }
            VStack(alignment: .leading, spacing: 12) {
                itemInfo(item, owned: owned, canAfford: canAfford)
                decorationButton(item, owned: owned, canAfford: canAfford)
            }
        }.padding(14)
    }

    private func itemInfo(_ item: Decoration, owned: Bool, canAfford: Bool) -> some View {
        HStack(spacing: 12) {
            PixelSprite(sprite: GameSprite(rawValue: item.id) ?? .leaf, size: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
                Text(owned ? (store.state.placement(for: item.id).isLocked ? "Locked in place" : "Drag to move in habitat") : "\(item.cost) leaves")
                    .font(.caption).foregroundStyle(.secondary)
                if !owned && !canAfford {
                    Text("\(item.cost - store.state.points) more to go").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func decorationButton(_ item: Decoration, owned: Bool, canAfford: Bool) -> some View {
        let locked = store.state.placement(for: item.id).isLocked
        return Button {
            if owned { store.setDecorationLocked(item.id, locked: !locked) }
            else { store.buy(item) }
        } label: {
            if owned { Label(locked ? "Unlock" : "Lock", systemImage: locked ? "lock.open.fill" : "lock.fill") }
            else { Text("Add").frame(minWidth: 28) }
        }.buttonStyle(PixelButtonStyle(secondary: owned))
            .disabled(!owned && !canAfford)
            .accessibilityLabel(owned ? "\(locked ? "Unlock" : "Lock") \(item.name)" : "Add \(item.name) for \(item.cost) leaves")
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
                                    Text(HabitatKind(rawValue: action.habitatID ?? "grove")?.title ?? "Willow Grove")
                                        .font(.caption2).foregroundStyle(.secondary)
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
