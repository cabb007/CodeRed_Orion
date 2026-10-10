import Foundation

final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    override func string(forKey defaultName: String) -> String? { values[defaultName] as? String }
    override func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
}

@main
@MainActor
struct HabitatStoreChecks {
    static func main() throws {
        checkDemoRewards()
        let defaults = MemoryDefaults(suiteName: "EcoGotchi.InMemoryChecks")!
        let store = HabitatStore(defaults: defaults)
        store.record(item: "Paper")
        precondition(store.state.points == 0 && store.state.actions.isEmpty, "Self-reporting cannot earn live rewards")
        let assessment = review()
        precondition(store.recordReviewedAction(assessment), "An approved receipt awards the fixed material reward")
        precondition(store.state.points == 30 && store.state.litter == 2)
        precondition(store.state.actions.first?.recyclingTip == assessment.tip)
        precondition(!store.recordReviewedAction(assessment), "Retrying the same receipt cannot award again")
        precondition(!store.recordReviewedAction(review(submissionID: assessment.submissionId)), "A different receipt for the same submission cannot award again")
        precondition(!store.recordReviewedAction(review(receiptID: assessment.receiptId)), "A reused receipt cannot award for a different submission")
        for invalid in [review(status: .rejected), review(status: .needsReview), review(leaves: 999), review(cleanup: 6), review(quality: "medium"), review(verification: "self_reported")] {
            precondition(!store.recordReviewedAction(invalid), "Uncertain, rejected or malformed rewards are refused")
        }
        for material in RecycledMaterial.allCases {
            precondition(review(leaves: material.leaves, material: material).isValidReward == (material.leaves > 0))
        }
        for evidence in ["printed_label", "material_icon", "nearby_sign"] {
            var iconReview = review()
            iconReview.localAcceptance = "recyclable_here"
            iconReview.acceptanceEvidence = evidence
            let decoded = try JSONDecoder().decode(RecyclingAssessment.self, from: JSONEncoder().encode(iconReview))
            precondition(decoded.isValidReward && !decoded.needsBinGuidance)
        }
        var uncertainBin = review(status: .needsReview, leaves: 0, cleanup: 0)
        uncertainBin.localAcceptance = "unknown"
        uncertainBin.acceptanceEvidence = "none"
        let decodedUncertainty = try JSONDecoder().decode(RecyclingAssessment.self, from: JSONEncoder().encode(uncertainBin))
        precondition(decodedUncertainty.needsBinGuidance && !decodedUncertainty.isValidReward)
        for (acceptance, evidence) in [("recyclable_here", "none"), ("unknown", "material_icon"), ("recyclable_here", "bin_color")] {
            var invalidBin = review()
            invalidBin.localAcceptance = acceptance
            invalidBin.acceptanceEvidence = evidence
            precondition(!store.recordReviewedAction(invalidBin), "Unsupported bin evidence cannot grant rewards")
        }
        // Existing cached receipts omit the new evidence fields.
        let legacy = try JSONDecoder().decode(RecyclingAssessment.self, from: JSONEncoder().encode(assessment))
        precondition(legacy.localAcceptance == nil && legacy.acceptanceEvidence == nil && legacy.isValidReward)
        let original = store.state

        // Developer controls cannot mutate a normal game.
        store.setPoints(9_000)
        store.setLitter(6)
        store.resetPreview()
        precondition(store.state.points == original.points && store.state.litter == original.litter)

        store.beginDeveloperMode()
        precondition(!store.recordReviewedAction(review()), "Live reviews cannot award while preview is active")
        store.setLitter(99)
        precondition(store.state.litter == 6)
        store.setLitter(-1)
        precondition(store.state.litter == 0)
        store.unlockPreview()
        precondition(store.state.unlockedAnimals.count == 4 && store.state.points == 200)
        store.buy(Decoration.all[0])
        precondition(store.state.ownedDecorations.contains("flowers") && store.state.points == 160)
        store.setDecoration("flowers", owned: false)
        precondition(!store.state.ownedDecorations.contains("flowers"))

        store.setLitter(4)
        store.developer.actionReward = 35
        store.developer.cleanupPerAction = 2
        store.record(item: "Test")
        precondition(store.state.litter == 2 && store.state.points == 195 && store.state.actions.last?.reward == 35)

        // Even if a preview causes saves or the app restarts, only the real game is on disk.
        let reloaded = HabitatStore(defaults: defaults)
        precondition(!reloaded.recordReviewedAction(assessment), "Receipt replay is blocked after relaunch")
        precondition(reloaded.state.points == original.points && reloaded.state.actions.count == original.actions.count)
        precondition(reloaded.state.ownedDecorations == original.ownedDecorations)
        store.beginDeveloperMode()
        store.endDeveloperMode()
        precondition(store.state.points == original.points && store.state.actions.count == original.actions.count)
        precondition(store.state.litter == original.litter && !store.isDeveloperMode)

        store.beginDeveloperMode()
        store.setLitter(0)
        store.advancePreview(hours: 4)
        precondition(store.state.litter == 1)
        store.setPollutionInterval(5)
        store.advancePreview(hours: 24)
        precondition(store.state.litter == 6)
        store.resetPreview()
        precondition(store.isDeveloperMode && store.state.points == 0 && store.state.litter == 3)
        store.endDeveloperMode()
        precondition(store.state.points == original.points && store.state.actions.count == original.actions.count)
        print("Store checks passed: reviewed rewards, replay protection, failure guards, preview isolation, purchases, timing, and restoration.")
    }

    static func checkDemoRewards() {
        let defaults = MemoryDefaults(suiteName: "EcoGotchi.DemoChecks")!
        let store = HabitatStore(defaults: defaults)
        precondition(store.isDemoRecycling, "The hackathon build starts in offline demo mode")
        let frames = ["bin", "item", "disposal"].map {
            RecyclingPhoto(role: $0, source: "camera", mimeType: "image/jpeg", capturedAt: "2026-10-10T12:00:00Z", data: "demo-photo")
        }
        let submission = RecyclingSubmission(submissionId: UUID(), photos: frames)
        precondition(!store.recordDemoAction(.init(submissionId: UUID(), photos: Array(frames.prefix(2)))), "Incomplete scans cannot award")
        precondition(store.recordDemoAction(submission), "Complete demo scans award without AI")
        precondition(store.state.points == 20 && store.state.litter == 2 && store.state.unlockedAnimals.count == 2)
        precondition(store.state.actions.last?.isDemo == true && store.state.actions.last?.verificationID == nil)
        precondition(!store.recordDemoAction(submission), "Repeated completion cannot award twice")
        let reloaded = HabitatStore(defaults: defaults)
        precondition(reloaded.state.points == 20 && reloaded.state.actions.last?.isDemo == true)
        precondition(!reloaded.recordDemoAction(submission), "Demo completion IDs survive relaunch")
        store.recyclingMode = .ai
        precondition(!HabitatStore(defaults: defaults).isDemoRecycling, "Recycling mode persists")
        precondition(!store.recordDemoAction(.init(submissionId: UUID(), photos: frames)), "AI mode cannot use the demo award path")
        store.recyclingMode = .demo
        store.beginDeveloperMode()
        precondition(!store.recordDemoAction(.init(submissionId: UUID(), photos: frames)), "Developer previews use temporary rewards")
        store.endDeveloperMode()
        precondition(store.state.points == 20 && store.state.actions.count == 1)
    }

    static func review(submissionID: UUID = UUID(), receiptID: UUID = UUID(), status: RecyclingAssessment.Status = .approved,
                       leaves: Int = 30, cleanup: Int = 1, quality: String = "high", verification: String = "gemini_visual_review",
                       material: RecycledMaterial = .aluminum) -> RecyclingAssessment {
        .init(submissionId: submissionID, receiptId: receiptID, reviewedAt: "2026-10-10T12:00:00.000Z", status: status,
              itemName: "Aluminum can", material: material, leaves: leaves, cleanup: cleanup,
              explanation: "Can entering labeled bin", tip: "Follow this bin’s instructions.", labelEvidence: "Empty cans",
              evidenceQuality: quality, verification: verification, limitation: "Visual review only")
    }
}
