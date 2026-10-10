import Foundation
import Combine

@MainActor
final class HabitatStore: ObservableObject {
    @Published private var session: HabitatSession
    @Published var developer = DeveloperOptions()
    @Published var recyclingMode: RecyclingMode {
        didSet { defaults.set(recyclingMode.rawValue, forKey: "ecogotchi.recyclingMode") }
    }
    private let key = "ecogotchi.habitat.v1"
    private let defaults: UserDefaults

    var state: HabitatState { session.state }
    var isDeveloperMode: Bool { session.isDeveloperMode }
    var isDemoRecycling: Bool { recyclingMode == .demo }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recyclingMode = defaults.string(forKey: "ecogotchi.recyclingMode").flatMap(RecyclingMode.init(rawValue:)) ?? .demo
        let saved = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(HabitatState.self, from: $0) }
        session = HabitatSession(state: saved ?? HabitatState())
        refresh()
    }

    func refresh() {
        guard !isDeveloperMode || !developer.pausePollution else { return }
        let interval = isDeveloperMode ? developer.pollutionInterval : 14_400
        guard Date().timeIntervalSince(state.lastPollution) >= interval else { return }
        session.state.advance(to: Date(), interval: interval)
        save()
    }

    func record(item: String) {
        guard isDeveloperMode else { return }
        session.state.recordAction(item: "[Preview] \(item)",
                                   reward: developer.actionReward,
                                   cleanup: developer.cleanupPerAction)
        save()
    }

    @discardableResult
    func recordDemoAction(_ submission: RecyclingSubmission) -> Bool {
        guard !isDeveloperMode, isDemoRecycling,
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
    func recordReviewedAction(_ assessment: RecyclingAssessment) -> Bool {
        guard !isDeveloperMode, assessment.isValidReward,
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

    func beginDeveloperMode() {
        guard !isDeveloperMode else { return }
        refresh()
        session.beginPreview()
        session.state.lastPollution = Date()
        developer = DeveloperOptions()
    }

    func endDeveloperMode() {
        session.endPreview()
        developer = DeveloperOptions()
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
        if target < state.actions.count {
            session.state.actions = Array(state.actions.prefix(target))
        } else {
            while state.actions.count < target {
                session.state.actions.append(.init(id: UUID(), date: Date(), item: "[Preview] Recycling action"))
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
    }

    func unlockPreview() {
        guard isDeveloperMode else { return }
        setActionCount(6)
        setPoints(200)
        setLitter(0)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(session.persistedState) {
            defaults.set(data, forKey: key)
        }
    }
}
