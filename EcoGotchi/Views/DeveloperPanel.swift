import SwiftUI

struct DeveloperPanel: View {
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.dismiss) private var dismiss
    @State private var showReset = false
    @State private var challengePreview: ChallengePreview?
    @State private var category = DeveloperCategory.habitat

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(store.state.condition.title).font(.headline)
                        Spacer()
                        Text("\(store.state.litter)/6 litter · \(store.state.points) leaves").font(.caption)
                    }
                    Text("Test changes only. Exit preview to restore your habitat.")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Controls", selection: $category) {
                        ForEach(DeveloperCategory.allCases) { group in Text(group.rawValue).tag(group) }
                    }.pickerStyle(.segmented)
                }

                if category == .habitat {
                    Section("Habitat condition") {
                        ForEach(HabitatCondition.allCases) { condition in
                            Button {
                                store.setLitter(condition.exampleLitter)
                            } label: {
                                HStack {
                                    Text(condition.title)
                                    Spacer()
                                    Text(conditionRange(condition)).font(.caption).foregroundStyle(.secondary)
                                    if store.state.condition == condition { Image(systemName: "checkmark.circle.fill") }
                                }
                            }
                        }
                        Stepper("Trash: \(store.state.litter) / 6", value: Binding(get: { store.state.litter }, set: store.setLitter), in: 0...6)
                        HStack {
                            Button("Drop trash") { store.setLitter(store.state.litter + 1) }.disabled(store.state.litter == 6)
                            Spacer()
                            Button("Clear trash") { store.setLitter(0) }.disabled(store.state.litter == 0)
                        }.buttonStyle(.borderless)
                    }

                    Section("Time & pollution") {
                        Toggle("Pause automatic trash", isOn: Binding(get: { store.developer.pausePollution }, set: store.setPollutionPaused))
                        Picker("Drop interval", selection: Binding(get: { store.developer.pollutionInterval }, set: store.setPollutionInterval)) {
                            Text("5 seconds").tag(5.0)
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("4 hours (normal)").tag(14_400.0)
                        }
                        HStack {
                            Button("Skip 4 hours") { store.advancePreview(hours: 4) }
                            Spacer()
                            Button("Skip 24 hours") { store.advancePreview(hours: 24) }
                        }.buttonStyle(.borderless)
                    }

                }

                if category == .friends {
                    Section("Animals") {
                        Stepper("Actions: \(store.state.actions.count)", value: Binding(get: { store.state.actions.count }, set: store.setActionCount), in: 0...30)
                        Text("Unlocks: Pip at 0, Fern at 1, Clover at 3, Maple at 6 actions.").font(.caption).foregroundStyle(.secondary)
                        Button("Unlock all animals") { store.setActionCount(6) }
                        Toggle("Keep animals out when polluted", isOn: $store.developer.ignoreRetreat)
                        ForEach(HabitatAnimal.all) { animal in
                            Toggle(isOn: animalBinding(animal.id)) {
                                HStack {
                                    PixelSprite(sprite: GameSprite(rawValue: animal.id) ?? .pip, size: 32)
                                    Text(animal.name)
                                    if store.state.actions.count < animal.requiredActions {
                                        Text("locked").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                }

                if category == .rewards {
                    Section("Rewards & decorations") {
                        Stepper("Leaves: \(store.state.points)", value: Binding(get: { store.state.points }, set: store.setPoints), in: 0...10_000, step: 20)
                        HStack {
                            Button("Set to 0") { store.setPoints(0) }
                            Spacer()
                            Button("Add 200") { store.setPoints(store.state.points + 200) }
                        }.buttonStyle(.borderless)
                        Stepper("Leaves per action: \(store.developer.actionReward)", value: $store.developer.actionReward, in: 0...100, step: 5)
                        Stepper("Trash cleared per action: \(store.developer.cleanupPerAction)", value: $store.developer.cleanupPerAction, in: 0...6)
                        Button("Simulate completed recycling") { store.record(item: "Developer test action") }
                        ForEach(Decoration.all) { item in
                            Toggle(isOn: Binding(get: { store.state.ownedDecorations.contains(item.id) }, set: { store.setDecoration(item.id, owned: $0) })) {
                                HStack {
                                    PixelSprite(sprite: GameSprite(rawValue: item.id) ?? .leaf, size: 32)
                                    Text(item.name)
                                }
                            }
                        }
                    }

                }

                if category == .tools {
                    Section("Camera & reward screens") {
                        Button("Test camera capture") { challengePreview = .camera }
                        Button("Guided capture demo") { challengePreview = .samplePhotos }
                        Button("Preview reward screen") { challengePreview = .reward }
                        Text("Practice bin → item → disposal with one camera session or sample artwork, including success effects and sounds. Developer scans automatically finish and only change the preview. Exit preview and choose AI review in Scan settings to test Gemini.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("Scene elements") {
                        Toggle("Animal movement", isOn: $store.developer.animateAnimals)
                        Toggle("Sparkles & pollution haze", isOn: $store.developer.showAtmosphere)
                        Toggle("Element labels", isOn: $store.developer.showLabels)
                        Toggle("Placement grid", isOn: $store.developer.showGrid)
                        HStack {
                            Text("Sprite size")
                            Slider(value: $store.developer.spriteScale, in: 0.5...1.8, step: 0.1)
                            Text("\(store.developer.spriteScale, specifier: "%.1f")×").monospacedDigit()
                        }
                        Text("The iPhone’s Reduce Motion setting takes priority over animation controls.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                }

                Section("Quick actions") {
                    Button("Thriving demo · all friends + 200 leaves") { store.unlockPreview() }
                    Button("Reset this preview", role: .destructive) { showReset = true }
                }
            }
            .scrollContentBackground(.hidden).background(Palette.cream)
            .navigationTitle("Developer mode").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Exit preview") { store.endDeveloperMode(); dismiss() }.font(.caption.bold())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.bold()).frame(width: 44, height: 44)
                    }.accessibilityLabel("Close developer controls, keep preview active")
                }
            }
            .confirmationDialog("Reset this preview to a new game? Your saved habitat stays unchanged.", isPresented: $showReset) {
                Button("Reset preview", role: .destructive) { store.resetPreview() }
            }
            .sheet(item: $challengePreview) { preview in
                RecyclingView(launchCameraOnOpen: preview == .camera,
                              useSamplePhotos: preview == .samplePhotos,
                              showRewardPreview: preview == .reward)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func animalBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { !store.developer.hiddenAnimals.contains(id) }, set: { visible in
            if visible { store.developer.hiddenAnimals.remove(id) }
            else { store.developer.hiddenAnimals.insert(id) }
        })
    }

    private func conditionRange(_ condition: HabitatCondition) -> String {
        switch condition {
        case .thriving: "0 litter"
        case .littered: "1–2 litter"
        case .tarnished: "3–4 litter"
        case .polluted: "5–6 litter"
        }
    }

    private enum DeveloperCategory: String, CaseIterable, Identifiable {
        case habitat = "Habitat", friends = "Friends", rewards = "Rewards", tools = "Tools"
        var id: String { rawValue }
    }

    private enum ChallengePreview: String, Identifiable {
        case camera, samplePhotos, reward
        var id: String { rawValue }
    }
}
