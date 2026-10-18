import Foundation

final class BackgroundDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func data(forKey key: String) -> Data? { values[key] as? Data }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
}

@MainActor
final class ReviewGate {
    var continuation: CheckedContinuation<RecyclingAssessment, Error>?
    func review(_ submission: RecyclingSubmission) async throws -> RecyclingAssessment {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ result: RecyclingAssessment) { continuation?.resume(returning: result); continuation = nil }
}

@main
@MainActor
struct BackgroundReviewChecks {
    static func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<1_000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        preconditionFailure("Review did not reach its expected state")
    }

    static func submission() -> RecyclingSubmission {
        .init(submissionId: UUID(), photos: ["bin", "item"].map {
            .init(role: $0, source: "camera", mimeType: "image/jpeg", capturedAt: "test", data: $0)
        })
    }

    static func receipt(_ submission: RecyclingSubmission) -> RecyclingAssessment {
        .init(submissionId: submission.submissionId, receiptId: UUID(), reviewedAt: "test",
              status: .approved, itemName: "Can", material: .aluminum, leaves: 30, cleanup: 1,
              explanation: "Likely recycling match", tip: "Check local rules", labelEvidence: "Recycling opening",
              evidenceQuality: "high", verification: "gemini_visual_review", limitation: "Visual only",
              localAcceptance: "likely_compatible", acceptanceEvidence: "bin_appearance", binType: "recycling")
    }

    static func setup() throws -> (HabitatStore, BackgroundDefaults) {
        let defaults = BackgroundDefaults()
        defaults.set(try JSONEncoder().encode(HabitatState(points: 0, litter: 3)), forKey: "ecogotchi.habitat.v1")
        let store = HabitatStore(defaults: defaults)
        store.recyclingMode = .ai
        return (store, defaults)
    }

    static func main() async throws {
        // The store owns a pending review independently of the capture screen.
        let (store, defaults) = try setup()
        let scan = submission(), gate = ReviewGate()
        try store.startScanReview(scan, using: gate.review)
        precondition(store.scanReview?.status == .reviewing && store.state.points == 0)
        do {
            try store.startScanReview(submission(), using: gate.review)
            preconditionFailure("Only one review should run at a time")
        } catch { }
        store.dismissScanReview()
        precondition(store.scanReview != nil, "Dismissing the sheet must not drop a pending job")
        store.selectHabitat(.ocean)
        let oceanLitter = store.state.litter
        try await waitUntil { gate.continuation != nil }
        let approved = receipt(scan)
        gate.finish(approved)
        try await waitUntil { store.scanReview?.status == .finished }
        precondition(store.state.points == 30 && store.state.habitat == .ocean && store.state.litter == oceanLitter)
        precondition(store.scanReview?.cleanup == 1 && store.scanReview?.habitat == .grove)
        store.selectHabitat(.grove)
        precondition(store.state.litter == 2 && store.state.actions.last?.habitatID == "grove")
        precondition(HabitatStore(defaults: defaults).state.points == 30, "Reward persists after relaunch")
        store.dismissScanReview()
        try store.startScanReview(scan) { _ in approved }
        try await waitUntil { store.scanReview?.status == .finished }
        precondition(store.state.points == 30 && store.scanReview?.alreadyRewarded == true)
        store.dismissScanReview()

        // A live review completes into the saved game while a developer preview is visible.
        let liveScan = submission(), liveGate = ReviewGate()
        try store.startScanReview(liveScan, using: liveGate.review)
        store.beginDeveloperMode()
        store.setPoints(999)
        try await waitUntil { liveGate.continuation != nil }
        liveGate.finish(receipt(liveScan))
        try await waitUntil { store.scanReview?.status == .finished }
        precondition(store.state.points == 999 && HabitatStore(defaults: defaults).state.points == 60)
        precondition(store.savedLeafTotal == 60, "A real review shows the saved total while preview is visible")
        store.endDeveloperMode()
        precondition(store.state.points == 60)
        store.dismissScanReview()

        // Preview rewards are temporary, and late callbacks cannot escape a closed preview.
        store.beginDeveloperMode()
        let previewScan = submission()
        try store.startScanReview(previewScan) { receipt($0) }
        try await waitUntil { store.scanReview?.status == .finished }
        precondition(store.state.points == 90 && HabitatStore(defaults: defaults).state.points == 60)
        store.endDeveloperMode()
        precondition(store.scanReview == nil && store.state.points == 60)
        store.beginDeveloperMode()
        let staleScan = submission(), staleGate = ReviewGate()
        try store.startScanReview(staleScan, using: staleGate.review)
        try await waitUntil { staleGate.continuation != nil }
        store.resetPreview()
        staleGate.finish(receipt(staleScan))
        await Task.yield()
        precondition(store.scanReview == nil && store.state.points == 0)
        store.endDeveloperMode()
        precondition(store.state.points == 60)

        // Cancellation cannot reward even if a transport ignores it and returns success.
        let cancelledScan = submission(), cancelledGate = ReviewGate()
        try store.startScanReview(cancelledScan, using: cancelledGate.review)
        try await waitUntil { cancelledGate.continuation != nil }
        store.cancelScanReview()
        cancelledGate.finish(receipt(cancelledScan))
        try await waitUntil { store.scanReview?.status == .failed }
        precondition(store.state.points == 60)
        store.dismissScanReview()

        // Retry retains the same submission; failures and foreign receipts never reward.
        var attempts = 0
        let retryScan = submission()
        try store.startScanReview(retryScan) { received in
            precondition(received.submissionId == retryScan.submissionId && received.photos.map(\.data) == retryScan.photos.map(\.data))
            attempts += 1
            if attempts == 1 { throw VerificationError.message("Offline") }
            return receipt(received)
        }
        try await waitUntil { store.scanReview?.status == .failed }
        precondition(store.state.points == 60 && attempts == 1)
        store.retryScanReview()
        try await waitUntil { store.scanReview?.status == .finished }
        precondition(store.state.points == 90 && attempts == 2)
        store.dismissScanReview()
        try store.startScanReview(submission()) { _ in approved }
        try await waitUntil { store.scanReview?.status == .failed }
        precondition(store.state.points == 90)
        store.dismissScanReview()
        try store.startScanReview(submission()) { received in
            var invalid = receipt(received)
            invalid.binType = "general_waste"
            return invalid
        }
        try await waitUntil { store.scanReview?.status == .failed }
        precondition(store.state.points == 90)
        print("Background review checks passed: pending, target habitat, persistence, duplicate protection, preview isolation, cancellation, retry, and invalid receipts.")
    }
}
