import Foundation

enum HabitatCondition: String, CaseIterable, Identifiable {
    case thriving, littered, tarnished, polluted

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var exampleLitter: Int {
        switch self { case .thriving: 0; case .littered: 2; case .tarnished: 4; case .polluted: 6 }
    }
    var assetName: String {
        switch self {
        case .thriving, .littered: "GroveThriving"
        case .tarnished: "GroveTarnished"
        case .polluted: "GrovePolluted"
        }
    }
    var message: String {
        switch self {
        case .thriving: "Clear water. Happy little friends."
        case .littered: "A little cleanup goes a long way."
        case .tarnished: "The grove is losing its glow."
        case .polluted: "Your friends are sheltering. Help the grove recover."
        }
    }
}

enum HabitatKind: String, Codable, CaseIterable, Identifiable {
    case grove, ocean, snow
    var id: String { rawValue }
    var previous: Self? { neighbor(offset: -1) }
    var next: Self? { neighbor(offset: 1) }
    private func neighbor(offset: Int) -> Self? {
        let habitats = Self.allCases
        guard let index = habitats.firstIndex(of: self), habitats.indices.contains(index + offset) else { return nil }
        return habitats[index + offset]
    }
    var title: String {
        switch self { case .grove: "Willow Grove"; case .ocean: "Coral Cove"; case .snow: "Snow Glade" }
    }
    var detail: String {
        switch self {
        case .grove: "A sunlit home for woodland friends."
        case .ocean: "A turquoise reef with a curious ocean crew."
        case .snow: "A snowy clearing for the coziest little explorers."
        }
    }
    var starterID: String {
        switch self { case .grove: "pip"; case .ocean: "bubbles"; case .snow: "waddles" }
    }
    var cleanAsset: String {
        switch self { case .grove: "GroveThriving"; case .ocean: "OceanReef"; case .snow: "SnowGlade" }
    }
    func asset(for condition: HabitatCondition) -> String {
        switch (self, condition) {
        case (.grove, _): condition.assetName
        case (_, .thriving): cleanAsset
        case (.ocean, .littered): "OceanLittered"
        case (.ocean, .tarnished): "OceanTarnished"
        case (.ocean, .polluted): "OceanPolluted"
        case (.snow, .littered): "SnowLittered"
        case (.snow, .tarnished): "SnowTarnished"
        case (.snow, .polluted): "SnowPolluted"
        }
    }
    var animals: [HabitatAnimal] { HabitatAnimal.all.filter { $0.habitat == self } }
    var decorations: [Decoration] { Decoration.all.filter { $0.habitat == self } }
    var foods: [PetFood] { PetFood.all.filter { $0.habitats.contains(self) } }
}

struct HabitatAnimal: Identifiable {
    let id: String
    let name: String
    let pettingSound: String
    let emoji: String
    let detail: String
    let requiredActions: Int
    var habitat: HabitatKind = .grove

    static let all: [HabitatAnimal] = [
        .init(id: "pip", name: "Pip", pettingSound: "chirp!", emoji: "🐣", detail: "Your very first woodland friend.", requiredActions: 0),
        .init(id: "fern", name: "Fern", pettingSound: "ribbit!", emoji: "🐸", detail: "A little frog with a big love for clean ponds.", requiredActions: 1),
        .init(id: "clover", name: "Clover", pettingSound: "purr!", emoji: "🐰", detail: "Always looking for a peaceful patch of grass.", requiredActions: 3),
        .init(id: "maple", name: "Maple", pettingSound: "yip!", emoji: "🦊", detail: "A shy visitor who stays when the grove feels like home.", requiredActions: 6),
        .init(id: "bubbles", name: "Bubbles", pettingSound: "blub!", emoji: "🐠", detail: "A tiny clownfish with a big sense of adventure.", requiredActions: 0, habitat: .ocean),
        .init(id: "shelly", name: "Shelly", pettingSound: "peep!", emoji: "🐢", detail: "A gentle sea turtle who loves a healthy reef.", requiredActions: 1, habitat: .ocean),
        .init(id: "inky", name: "Inky", pettingSound: "pop!", emoji: "🐙", detail: "Eight arms, endless hugs.", requiredActions: 3, habitat: .ocean),
        .init(id: "fin", name: "Fin", pettingSound: "click!", emoji: "🐬", detail: "A playful dolphin who follows the bubbles.", requiredActions: 6, habitat: .ocean),
        .init(id: "waddles", name: "Waddles", pettingSound: "honk!", emoji: "🐧", detail: "Your cheerful guide to the snowy glade.", requiredActions: 0, habitat: .snow),
        .init(id: "flurry", name: "Flurry", pettingSound: "yip!", emoji: "🦊", detail: "A fluffy arctic fox with warm little paws.", requiredActions: 1, habitat: .snow),
        .init(id: "pebble", name: "Pebble", pettingSound: "arf!", emoji: "🦭", detail: "A round seal who loves a cozy snowbank.", requiredActions: 3, habitat: .snow),
        .init(id: "snowdrop", name: "Snowdrop", pettingSound: "purr!", emoji: "🐇", detail: "A snow hare with springy feet and a soft heart.", requiredActions: 6, habitat: .snow)
    ]
}

struct Decoration: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let cost: Int
    var habitat: HabitatKind = .grove
    var x = 0.16
    var y = 0.73
    var scale = 0.14

    static let all: [Decoration] = [
        .init(id: "flowers", name: "Wildflowers", emoji: "🌼", cost: 40),
        .init(id: "mushrooms", name: "Mushroom nook", emoji: "🍄", cost: 60, x: 0.86, y: 0.66, scale: 0.13),
        .init(id: "house", name: "Little hideaway", emoji: "🏡", cost: 100, x: 0.21, y: 0.51, scale: 0.20),
        .init(id: "bench", name: "Woodland bench", emoji: "🪵", cost: 50, x: 0.75, y: 0.71, scale: 0.19),
        .init(id: "lantern", name: "Firefly lantern", emoji: "🏮", cost: 35, x: 0.82, y: 0.56),
        .init(id: "fernPlant", name: "Fern patch", emoji: "🌿", cost: 25, x: 0.21, y: 0.63),
        .init(id: "coral", name: "Peach coral", emoji: "🪸", cost: 40, habitat: .ocean, x: 0.18, y: 0.67, scale: 0.18),
        .init(id: "pearl", name: "Pearl hideaway", emoji: "🐚", cost: 60, habitat: .ocean, x: 0.80, y: 0.71, scale: 0.17),
        .init(id: "sandcastle", name: "Sandcastle", emoji: "🏰", cost: 90, habitat: .ocean, x: 0.28, y: 0.59, scale: 0.21),
        .init(id: "igloo", name: "Tiny igloo", emoji: "🧊", cost: 90, habitat: .snow, x: 0.20, y: 0.58, scale: 0.22),
        .init(id: "snowman", name: "Snow buddy", emoji: "☃️", cost: 40, habitat: .snow, x: 0.79, y: 0.66, scale: 0.16),
        .init(id: "spruce", name: "Frosted spruce", emoji: "🌲", cost: 55, habitat: .snow, x: 0.17, y: 0.71, scale: 0.18)
    ]
}

struct PetFood: Identifiable {
    let id: String
    let name: String
    let cost: Int
    let detail: String
    let habitats: Set<HabitatKind>
    static let all: [PetFood] = [
        .init(id: "berries", name: "Berry basket", cost: 5, detail: "A sweet woodland snack.", habitats: [.grove]),
        .init(id: "kelp", name: "Kelp bites", cost: 5, detail: "A little reef-side treat.", habitats: [.ocean]),
        .init(id: "crunch", name: "Star crunch", cost: 8, detail: "A favorite in every habitat.", habitats: [.grove, .ocean, .snow]),
        .init(id: "apple", name: "Apple snack", cost: 4, detail: "A crisp little pick-me-up.", habitats: [.grove, .snow])
    ]
}

struct HabitatProgress: Codable {
    var litter = 3
    var lastPollution = Date()
}

struct EcoAction: Codable, Identifiable {
    let id: UUID
    let date: Date
    let item: String
    var leavesEarned: Int? = nil
    var verificationID: UUID? = nil
    var submissionID: UUID? = nil
    var material: String? = nil
    var recyclingTip: String? = nil
    var source: String? = nil
    var habitatID: String? = nil

    var isDemo: Bool { source == "demo" }

    var reward: Int { leavesEarned ?? 20 }
}

struct DecorationPlacement: Codable, Equatable {
    // Relative to the visible play area, so saved layouts also fit a different screen size.
    var x: Double?
    var y: Double?
    var isLocked = false
}

struct HabitatState: Codable {
    var points = 0
    var litter = 3
    var actions: [EcoAction] = []
    var ownedDecorations: Set<String> = []
    var lastPollution = Date()
    // Optional for compatibility with habitats saved before movable decorations.
    var decorationPlacements: [String: DecorationPlacement]? = nil

    var habitatID: String? = nil
    var otherHabitats: [String: HabitatProgress]? = nil
    var foodInventory: [String: Int]? = nil
    var petMeals: [String: Int]? = nil

    var habitat: HabitatKind { HabitatKind(rawValue: habitatID ?? "grove") ?? .grove }
    var habitatActionCount: Int { actions.filter { ($0.habitatID ?? "grove") == habitat.rawValue }.count }

    mutating func selectHabitat(_ destination: HabitatKind, at now: Date = Date()) {
        guard destination != habitat else { return }
        let previousID = habitat.rawValue
        let previousProgress = HabitatProgress(litter: litter, lastPollution: lastPollution)
        if otherHabitats == nil { otherHabitats = [:] }
        otherHabitats?[previousID] = previousProgress
        let progress = otherHabitats?[destination.rawValue] ?? HabitatProgress(lastPollution: now)
        habitatID = destination.rawValue
        litter = progress.litter
        lastPollution = progress.lastPollution
    }

    func foodCount(_ id: String) -> Int { max(0, foodInventory?[id] ?? 0) }

    @discardableResult
    mutating func buyFood(_ id: String) -> Bool {
        guard let food = PetFood.all.first(where: { $0.id == id }), food.habitats.contains(habitat),
              points >= food.cost, foodCount(id) < 99 else { return false }
        points -= food.cost
        let count = foodCount(id) + 1
        if foodInventory == nil { foodInventory = [:] }
        foodInventory?[id] = count
        return true
    }

    @discardableResult
    mutating func feed(_ animalID: String, foodID: String, includeSheltering: Bool = false) -> Bool {
        let available = includeSheltering ? unlockedAnimals : residentAnimals
        guard let food = PetFood.all.first(where: { $0.id == foodID }), food.habitats.contains(habitat),
              foodCount(foodID) > 0, available.contains(where: { $0.id == animalID }) else { return false }
        let remaining = foodCount(foodID) - 1
        let meals = min(999_999, max(0, petMeals?[animalID] ?? 0) + 1)
        foodInventory?[foodID] = remaining
        if petMeals == nil { petMeals = [:] }
        petMeals?[animalID] = meals
        return true
    }

    func placement(for id: String) -> DecorationPlacement {
        decorationPlacements?[id] ?? DecorationPlacement()
    }

    @discardableResult
    mutating func moveDecoration(_ id: String, x: Double, y: Double) -> Bool {
        guard ownedDecorations.contains(id), habitat.decorations.contains(where: { $0.id == id }),
              !placement(for: id).isLocked, x.isFinite, y.isFinite else { return false }
        var placement = placement(for: id)
        placement.x = max(0, min(1, x))
        placement.y = max(0, min(1, y))
        if decorationPlacements == nil { decorationPlacements = [:] }
        decorationPlacements?[id] = placement
        return true
    }

    @discardableResult
    mutating func setDecorationLocked(_ id: String, locked: Bool) -> Bool {
        guard ownedDecorations.contains(id), habitat.decorations.contains(where: { $0.id == id }) else { return false }
        var placement = placement(for: id)
        placement.isLocked = locked
        if decorationPlacements == nil { decorationPlacements = [:] }
        decorationPlacements?[id] = placement
        return true
    }

    mutating func resetDecorationLayout() {
        for item in habitat.decorations { decorationPlacements?.removeValue(forKey: item.id) }
        if decorationPlacements?.isEmpty == true { decorationPlacements = nil }
    }

    var health: Int { max(0, 100 - litter * 15) }
    var cleanedFraction: Double { Double(6 - min(6, max(0, litter))) / 6 }
    var cleanedPercent: Int { Int((cleanedFraction * 100).rounded()) }
    var condition: HabitatCondition {
        switch litter {
        case ...0: .thriving
        case 1...2: .littered
        case 3...4: .tarnished
        default: .polluted
        }
    }
    var unlockedAnimals: [HabitatAnimal] {
        habitat.animals.filter { habitatActionCount >= $0.requiredActions }
    }
    var nextAnimal: HabitatAnimal? {
        habitat.animals.first { habitatActionCount < $0.requiredActions }
    }
    var residentAnimals: [HabitatAnimal] {
        unlockedAnimals.filter { condition != .polluted || $0.requiredActions == 0 }
    }

    // Progress is kept even when animals retreat from a polluted habitat.
    mutating func advance(to now: Date, interval: TimeInterval = 4 * 60 * 60) {
        guard interval.isFinite, interval > 0 else { return }
        let elapsed = now.timeIntervalSince(lastPollution)
        guard elapsed.isFinite, elapsed >= interval else { return }
        litter = min(6, litter + Int(min(6, floor(elapsed / interval))))
        // Keep any partial interval so refreshing never delays the next drop.
        lastPollution = now.addingTimeInterval(-elapsed.truncatingRemainder(dividingBy: interval))
    }

    mutating func recordAction(item: String, at date: Date = Date(), reward: Int = 20, cleanup: Int = 1) {
        let awarded = max(0, min(100, reward))
        actions.append(.init(id: UUID(), date: date, item: item, leavesEarned: awarded, habitatID: habitat.rawValue))
        points += awarded
        litter = max(0, litter - max(0, min(6, cleanup)))
    }

    @discardableResult
    mutating func purchase(_ decoration: Decoration) -> Bool {
        guard let listed = habitat.decorations.first(where: { $0.id == decoration.id }),
              !ownedDecorations.contains(listed.id), points >= listed.cost else { return false }
        points -= listed.cost
        ownedDecorations.insert(listed.id)
        return true
    }
}

// A developer session never changes what is written as the user's saved game.
struct HabitatSession {
    var state: HabitatState
    private var liveSnapshot: HabitatState?

    init(state: HabitatState) { self.state = state }

    var isDeveloperMode: Bool { liveSnapshot != nil }
    var persistedState: HabitatState { liveSnapshot ?? state }

    // A real scan may finish while the user is trying developer preview.
    mutating func updateSavedGame(_ update: (inout HabitatState) -> Void) {
        if var live = liveSnapshot {
            update(&live)
            liveSnapshot = live
        } else { update(&state) }
    }

    mutating func beginPreview() {
        guard liveSnapshot == nil else { return }
        liveSnapshot = state
    }

    mutating func endPreview() {
        guard let liveSnapshot else { return }
        state = liveSnapshot
        self.liveSnapshot = nil
    }
}

struct DeveloperOptions {
    var pausePollution = true
    var pollutionInterval: TimeInterval = 14_400
    var actionReward = 20
    var cleanupPerAction = 1
    var animateAnimals = true
    var animateHabitat = true
    var showAtmosphere = true
    var showLabels = false
    var showGrid = false
    var ignoreRetreat = false
    var spriteScale = 1.0
    var hiddenAnimals: Set<String> = []
}
