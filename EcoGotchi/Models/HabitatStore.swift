import Foundation
import Combine

@MainActor
final class HabitatStore: ObservableObject {
    @Published private var session: HabitatSession
    @Published var developer = DeveloperOptions()
    @Published private(set) var selectedFoodID: String?
    @Published private(set) var scanReview: ScanReview?
    private var scanReviewTask: Task<Void, Never>?
    private var reviewSubmission: RecyclingSubmission?
    private var reviewer: (@MainActor (RecyclingSubmission) async throws -> RecyclingAssessment)?
    private var reviewAttemptID = UUID()
    private var previewID: UUID?
    @Published var recyclingMode: RecyclingMode {
        didSet { defaults.set(recyclingMode.rawValue, forKey: "ecogotchi.recyclingMode") }
    }
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
              submission.photos.map(\.role) == ["bin", "item"],
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
        guard !isDeveloperMode else { return false }
        return applyReviewedAction(assessment)
    }

    @discardableResult
    func recordPreviewReviewedAction(_ assessment: RecyclingAssessment) -> Bool {
        guard isDeveloperMode, recyclingMode == .ai else { return false }
        return applyReviewedAction(assessment)
    }

    private func applyReviewedAction(_ assessment: RecyclingAssessment) -> Bool {
        let preview = isDeveloperMode
        let habitat = state.habitat
        let applied = Self.apply(assessment, to: &session.state, habitat: habitat, preview: preview)
        save()
        return applied != nil
    }

    private static func apply(_ assessment: RecyclingAssessment, to state: inout HabitatState,
                              habitat: HabitatKind, preview: Bool) -> Int? {
        guard assessment.isValidReward,
              !state.actions.contains(where: { $0.verificationID == assessment.receiptId || $0.submissionID == assessment.submissionId }) else { return nil }
        // Change a copy so a late result never switches the visible habitat or food selection.
        var updated = state
        let visibleHabitat = updated.habitat
        updated.selectHabitat(habitat)
        let before = updated.litter
        updated.recordAction(item: preview ? "[Preview] \(assessment.itemName)" : assessment.itemName,
                             reward: assessment.leaves, cleanup: assessment.cleanup)
        let index = updated.actions.count - 1
        updated.actions[index].verificationID = assessment.receiptId
        updated.actions[index].submissionID = assessment.submissionId
        updated.actions[index].material = assessment.material.rawValue
        updated.actions[index].recyclingTip = assessment.tip
        let cleared = before - updated.litter
        updated.selectHabitat(visibleHabitat)
        state = updated
        return cleared
    }

    func startScanReview(_ submission: RecyclingSubmission,
                         using reviewer: @escaping @MainActor (RecyclingSubmission) async throws -> RecyclingAssessment) throws {
        guard scanReview == nil else { throw VerificationError.message("Finish or dismiss your current review first.") }
        guard recyclingMode == .ai, submission.photos.map(\.role) == ["bin", "item"] else {
            throw VerificationError.message("Capture the bin and item in Actual mode first.")
        }
        reviewSubmission = submission
        self.reviewer = reviewer
        scanReview = ScanReview(id: submission.submissionId, habitat: state.habitat, previewID: previewID)
        runScanReview()
    }

    func retryScanReview() {
        guard scanReview?.status == .failed, reviewSubmission != nil else { return }
        runScanReview()
    }

    func cancelScanReview() {
        guard scanReview?.status == .reviewing else { return }
        scanReview?.cancelling = true
        scanReviewTask?.cancel()
    }

    func dismissScanReview() {
        guard scanReview?.status != .reviewing else { return }
        clearScanReview()
    }

    private func clearScanReview() {
        reviewAttemptID = UUID()
        scanReviewTask?.cancel()
        scanReviewTask = nil
        reviewSubmission = nil
        reviewer = nil
        scanReview = nil
    }

    private func runScanReview() {
        guard let submission = reviewSubmission, let reviewer, var job = scanReview else { return }
        job.status = .reviewing
        job.startedAt = Date()
        job.message = nil
        job.cancelling = false
        scanReview = job
        let attempt = UUID()
        reviewAttemptID = attempt
        scanReviewTask = Task { @MainActor [weak self] in
            do {
                let assessment = try await reviewer(submission)
                try Task.checkCancellation()
                guard let self, self.reviewAttemptID == attempt, var current = self.scanReview else { return }
                guard assessment.submissionId == submission.submissionId,
                      assessment.status != .approved || assessment.isValidReward else {
                    throw VerificationError.message("The review didn’t match this scan. No leaves were added. Retry the same photos.")
                }
                var cleared: Int?
                if let preview = current.previewID {
                    guard self.previewID == preview, self.isDeveloperMode else { return }
                    cleared = Self.apply(assessment, to: &self.session.state, habitat: current.habitat, preview: true)
                } else {
                    self.session.updateSavedGame {
                        cleared = Self.apply(assessment, to: &$0, habitat: current.habitat, preview: false)
                    }
                }
                self.save()
                current.assessment = assessment
                current.leaves = cleared != nil ? assessment.leaves : 0
                current.cleanup = cleared ?? 0
                current.alreadyRewarded = assessment.status == .approved && cleared == nil
                current.status = .finished
                self.scanReview = current
                self.reviewSubmission = nil
                self.reviewer = nil
                self.scanReviewTask = nil
            } catch {
                guard let self, self.reviewAttemptID == attempt else { return }
                self.scanReview?.status = .failed
                self.scanReview?.cancelling = false
                self.scanReview?.message = error is CancellationError
                    ? "Review cancelled. Your photos are ready to retry; no leaves were added."
                    : error.localizedDescription
                self.scanReviewTask = nil
            }
        }
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
        session.beginPreview()
        previewID = UUID()
        session.state.lastPollution = Date()
        developer = DeveloperOptions()
        selectedFoodID = nil
    }

    func endDeveloperMode() {
        if scanReview?.previewID != nil { clearScanReview() }
        previewID = nil
        session.endPreview()
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
        if scanReview?.previewID != nil { clearScanReview() }
        previewID = UUID()
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

struct ScanReview: Identifiable {
    enum Status { case reviewing, finished, failed }
    let id: UUID
    let habitat: HabitatKind
    let previewID: UUID?
    var status = Status.reviewing
    var startedAt = Date()
    var cancelling = false
    var assessment: RecyclingAssessment?
    var leaves = 0
    var cleanup = 0
    var alreadyRewarded = false
    var message: String?

    var title: String {
        switch status {
        case .reviewing: return cancelling ? "Cancelling review…" : "Reviewing scan…"
        case .failed: return "Scan needs attention"
        case .finished:
            if leaves > 0 { return "+\(leaves) leaves\(previewID == nil ? "" : " · preview")" }
            if alreadyRewarded { return "Scan already rewarded" }
            return assessment?.needsBinGuidance == true ? "Bin unclear" : "Review ready · no leaves"
        }
    }
}
