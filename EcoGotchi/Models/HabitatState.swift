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

struct HabitatAnimal: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let detail: String
    let requiredActions: Int

    static let all: [HabitatAnimal] = [
        .init(id: "pip", name: "Pip", emoji: "🐣", detail: "Your very first woodland friend.", requiredActions: 0),
        .init(id: "fern", name: "Fern", emoji: "🐸", detail: "A little frog with a big love for clean ponds.", requiredActions: 1),
        .init(id: "clover", name: "Clover", emoji: "🐰", detail: "Always looking for a peaceful patch of grass.", requiredActions: 3),
        .init(id: "maple", name: "Maple", emoji: "🦊", detail: "A shy visitor who stays when the grove feels like home.", requiredActions: 6)
    ]
}

struct Decoration: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let cost: Int

    static let all: [Decoration] = [
        .init(id: "flowers", name: "Wildflowers", emoji: "🌼", cost: 40),
        .init(id: "mushrooms", name: "Mushroom nook", emoji: "🍄", cost: 60),
        .init(id: "house", name: "Little hideaway", emoji: "🏡", cost: 100)
    ]
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

    var isDemo: Bool { source == "demo" }

    var reward: Int { leavesEarned ?? 20 }
}

struct HabitatState: Codable {
    var points = 0
    var litter = 3
    var actions: [EcoAction] = []
    var ownedDecorations: Set<String> = []
    var lastPollution = Date()

    var health: Int { max(0, 100 - litter * 15) }
    var condition: HabitatCondition {
        switch litter {
        case ...0: .thriving
        case 1...2: .littered
        case 3...4: .tarnished
        default: .polluted
        }
    }
    var unlockedAnimals: [HabitatAnimal] {
        HabitatAnimal.all.filter { actions.count >= $0.requiredActions }
    }
    var nextAnimal: HabitatAnimal? {
        HabitatAnimal.all.first { actions.count < $0.requiredActions }
    }
    var residentAnimals: [HabitatAnimal] {
        unlockedAnimals.filter { condition != .polluted || $0.id == "pip" }
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
        actions.append(.init(id: UUID(), date: date, item: item, leavesEarned: awarded))
        points += awarded
        litter = max(0, litter - max(0, min(6, cleanup)))
    }

    @discardableResult
    mutating func purchase(_ decoration: Decoration) -> Bool {
        guard !ownedDecorations.contains(decoration.id), points >= decoration.cost else { return false }
        points -= decoration.cost
        ownedDecorations.insert(decoration.id)
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
    var showAtmosphere = true
    var showLabels = false
    var showGrid = false
    var ignoreRetreat = false
    var spriteScale = 1.0
    var hiddenAnimals: Set<String> = []
}
