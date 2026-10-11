import Foundation
import Combine

@MainActor
final class HabitatStore: ObservableObject {
    @Published private var session: HabitatSession
    @Published var developer = DeveloperOptions()
    @Published private(set) var selectedFoodID: String?
    @Published var recyclingMode: RecyclingMode {
        didSet { if !isDeveloperMode { defaults.set(recyclingMode.rawValue, forKey: "ecogotchi.recyclingMode") } }
    }
    @Published var scanSounds = true {
        didSet { if !isDeveloperMode { defaults.set(scanSounds, forKey: "ecogotchi.scanSounds") } }
    }
    @Published private(set) var modeSessionID = UUID()
    private var savedPreferences: (RecyclingMode, Bool)?
    func isCurrentSession(_ id: UUID) -> Bool { id == modeSessionID }
    private let key = "ecogotchi.habitat.v1"
    private let defaults: UserDefaults

    var state: HabitatState { session.state }
    var isDeveloperMode: Bool { session.isDeveloperMode }
    var isDemoRecycling: Bool { recyclingMode == .demo }
    var selectedFood: PetFood? {
        PetFood.all.first { $0.id == selectedFoodID && $0.habitats.contains(state.habitat) && state.foodCount($0.id) > 0 }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recyclingMode = defaults.string(forKey: "ecogotchi.recyclingMode").flatMap(RecyclingMode.init(rawValue:)) ?? .demo
        let saved = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(HabitatState.self, from: $0) }
        session = HabitatSession(state: saved ?? HabitatState())
        scanSounds = defaults.object(forKey: "ecogotchi.scanSounds") as? Bool ?? true
        refresh()
    }

    func refresh() {
        guard !isDeveloperMode || !developer.pausePollution else { return }
        let interval = isDeveloperMode ? developer.pollutionInterval : 14_400
        guard Date().timeIntervalSince(state.lastPollution) >= interval else { return }
        session.state.advance(to: Date(), interval: interval)
        save()
    }

    func record(item: String, sessionID: UUID? = nil) {
        guard isDeveloperMode, sessionID == nil || sessionID == modeSessionID else { return }
        session.state.recordAction(item: "[Preview] \(item)",
                                   reward: developer.actionReward,
                                   cleanup: developer.cleanupPerAction)
        save()
    }

    @discardableResult
    func recordDemoAction(_ submission: RecyclingSubmission, sessionID: UUID? = nil) -> Bool {
        guard sessionID == nil || sessionID == modeSessionID, !isDeveloperMode, isDemoRecycling,
              submission.photos.map(\.role) == ["bin", "item", "disposal"],
              submission.photos.allSatisfy({ $0.source == "camera" && !$0.data.isEmpty }),
              !state.actions.contains(where: { $0.submissionID == submission.submissionId }) else { return false }
        session.state.recordAction(item: "Recycling demo", reward: RecyclingMode.demoLeaves, cleanup: 1)
        let index = session.state.actions.count - 1
        session.state.actions[index].submissionID = submission.submissionId
        session.state.actions[index].source = "demo"
        save()
        return true
    }

    @discardableResult
    func recordReviewedAction(_ assessment: RecyclingAssessment, sessionID: UUID? = nil) -> Bool {
        guard sessionID == nil || sessionID == modeSessionID, !isDeveloperMode, assessment.isValidReward,
              !state.actions.contains(where: { $0.verificationID == assessment.receiptId || $0.submissionID == assessment.submissionId }) else { return false }
        session.state.recordAction(item: assessment.itemName, reward: assessment.leaves, cleanup: assessment.cleanup)
        let index = session.state.actions.count - 1
        session.state.actions[index].verificationID = assessment.receiptId
        session.state.actions[index].submissionID = assessment.submissionId
        session.state.actions[index].material = assessment.material.rawValue
        session.state.actions[index].recyclingTip = assessment.tip
        save()
        return true
    }

    func buy(_ decoration: Decoration) { session.state.purchase(decoration); save() }

    func selectHabitat(_ habitat: HabitatKind) {
        refresh()
        session.state.selectHabitat(habitat)
        selectedFoodID = nil
        refresh()
        save()
    }

    @discardableResult
    func buyFood(_ id: String) -> Bool {
        guard session.state.buyFood(id) else { return false }
        save()
        return true
    }

    func selectFood(_ id: String?) {
        selectedFoodID = id.flatMap { candidate in
            state.habitat.foods.contains(where: { $0.id == candidate }) && state.foodCount(candidate) > 0 ? candidate : nil
        }
    }

    @discardableResult
    func feedPet(_ id: String) -> Bool {
        let includeSheltering = isDeveloperMode && developer.ignoreRetreat
        guard let food = selectedFood, session.state.feed(id, foodID: food.id, includeSheltering: includeSheltering) else { return false }
        if state.foodCount(food.id) == 0 { selectedFoodID = nil }
        save()
        return true
    }

    func stockPreviewFood() {
        guard isDeveloperMode else { return }
        if session.state.foodInventory == nil { session.state.foodInventory = [:] }
        for food in PetFood.all { session.state.foodInventory?[food.id] = 5 }
    }

    func setPreviewFoodCount(_ id: String, count: Int) {
        guard isDeveloperMode, PetFood.all.contains(where: { $0.id == id }) else { return }
        if session.state.foodInventory == nil { session.state.foodInventory = [:] }
        session.state.foodInventory?[id] = min(99, max(0, count))
        if count <= 0 && selectedFoodID == id { selectedFoodID = nil }
    }

    func moveDecoration(_ id: String, x: Double, y: Double) {
        if session.state.moveDecoration(id, x: x, y: y) { save() }
    }

    func setDecorationLocked(_ id: String, locked: Bool) {
        if session.state.setDecorationLocked(id, locked: locked) { save() }
    }

    func resetDecorationLayout() { session.state.resetDecorationLayout(); save() }

    func beginDeveloperMode() {
        guard !isDeveloperMode else { return }
        refresh()
        savedPreferences = (recyclingMode, scanSounds)
        modeSessionID = UUID()
        session.beginPreview()
        recyclingMode = .demo
        session.state.lastPollution = Date()
        developer = DeveloperOptions()
        selectedFoodID = nil
    }

    func endDeveloperMode() {
        guard isDeveloperMode else { return }
        modeSessionID = UUID()
        session.endPreview()
        if let savedPreferences {
            recyclingMode = savedPreferences.0
            scanSounds = savedPreferences.1
        }
        savedPreferences = nil
        developer = DeveloperOptions()
        selectedFoodID = nil
        refresh()
    }

    func setLitter(_ amount: Int) {
        guard isDeveloperMode else { return }
        session.state.litter = min(6, max(0, amount))
        session.state.lastPollution = Date()
    }

    func setPoints(_ amount: Int) {
        guard isDeveloperMode else { return }
        session.state.points = min(10_000, max(0, amount))
    }

    func setActionCount(_ count: Int) {
        guard isDeveloperMode else { return }
        let target = max(0, min(30, count))
        if target < state.habitatActionCount {
            var kept = 0
            let current = state.habitat.rawValue
            session.state.actions = state.actions.filter { action in
                guard (action.habitatID ?? "grove") == current else { return true }
                kept += 1
                return kept <= target
            }
        } else {
            while state.habitatActionCount < target {
                session.state.actions.append(.init(id: UUID(), date: Date(), item: "[Preview] Recycling action", habitatID: state.habitat.rawValue))
            }
        }
    }

    func setDecoration(_ id: String, owned: Bool) {
        guard isDeveloperMode, Decoration.all.contains(where: { $0.id == id }) else { return }
        if owned { session.state.ownedDecorations.insert(id) }
        else { session.state.ownedDecorations.remove(id) }
    }

    func advancePreview(hours: Double) {
        guard isDeveloperMode, hours.isFinite, hours > 0 else { return }
        session.state.lastPollution = Date().addingTimeInterval(-min(hours, 168) * 3600)
        session.state.advance(to: Date(), interval: developer.pollutionInterval)
    }

    func setPollutionInterval(_ interval: TimeInterval) {
        guard isDeveloperMode else { return }
        developer.pollutionInterval = max(5, min(14_400, interval))
        session.state.lastPollution = Date()
    }

    func setPollutionPaused(_ paused: Bool) {
        guard isDeveloperMode else { return }
        developer.pausePollution = paused
        session.state.lastPollution = Date()
    }

    func resetPreview() {
        guard isDeveloperMode else { return }
        session.state = HabitatState()
        developer = DeveloperOptions()
        selectedFoodID = nil
    }

    func unlockPreview() {
        guard isDeveloperMode else { return }
        setActionCount(6)
        setPoints(200)
        setLitter(0)
        stockPreviewFood()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(session.persistedState) {
            defaults.set(data, forKey: key)
        }
    }
}
