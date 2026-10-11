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
    static func checkDecorationLayouts() throws {
        let defaults = MemoryDefaults(suiteName: "Recycli.LayoutChecks")!
        let seed = HabitatState(points: 200, ownedDecorations: ["flowers", "house"])
        let saved = try JSONEncoder().encode(seed)
        defaults.set(saved, forKey: "ecogotchi.habitat.v1")
        let store = HabitatStore(defaults: defaults)
        precondition(!store.state.placement(for: "flowers").isLocked)
        store.moveDecoration("mushrooms", x: 0.5, y: 0.5)
        store.setDecorationLocked("mushrooms", locked: true)
        precondition(store.state.decorationPlacements == nil, "Unowned decorations cannot be placed or locked")
        store.moveDecoration("flowers", x: .nan, y: 0.5)
        precondition(store.state.decorationPlacements == nil, "Invalid coordinates cannot corrupt the save")
        store.moveDecoration("flowers", x: -1, y: 5)
        precondition(store.state.placement(for: "flowers").x == 0 && store.state.placement(for: "flowers").y == 1)
        store.moveDecoration("flowers", x: 0.3, y: 0.7)
        store.setDecorationLocked("flowers", locked: true)
        store.moveDecoration("flowers", x: 0.9, y: 0.1)
        precondition(store.state.placement(for: "flowers").x == 0.3, "Locked decorations reject movement at the model layer")
        let restored = HabitatStore(defaults: defaults)
        precondition(restored.state.placement(for: "flowers") == store.state.placement(for: "flowers"), "Positions and locks survive reopening")
        precondition(restored.state.points == 200 && restored.state.ownedDecorations == seed.ownedDecorations)
        store.setDecorationLocked("flowers", locked: false)
        store.moveDecoration("flowers", x: 0.4, y: 0.6)
        precondition(store.state.placement(for: "flowers").x == 0.4, "Unlocking allows movement again")
        store.setDecorationLocked("house", locked: true)
        precondition(store.state.placement(for: "house").x == nil, "Locking an unmoved decoration preserves its default position")
        let live = store.state.decorationPlacements
        store.beginDeveloperMode()
        store.moveDecoration("flowers", x: 0.8, y: 0.2)
        store.setDecorationLocked("flowers", locked: true)
        precondition(HabitatStore(defaults: defaults).state.decorationPlacements == live, "Preview layout changes never save over the real habitat")
        store.resetDecorationLayout()
        precondition(store.state.decorationPlacements == nil)
        precondition(HabitatStore(defaults: defaults).state.decorationPlacements == live, "Preview layout resets stay isolated")
        store.endDeveloperMode()
        precondition(store.state.decorationPlacements == live, "Leaving preview restores real positions and locks")
        store.resetDecorationLayout()
        precondition(HabitatStore(defaults: defaults).state.decorationPlacements == nil, "Reset positions and locks persists")
        var legacy = try JSONSerialization.jsonObject(with: saved) as! [String: Any]
        legacy.removeValue(forKey: "decorationPlacements")
        let migrated = try JSONDecoder().decode(HabitatState.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(migrated.points == 200 && migrated.ownedDecorations == seed.ownedDecorations && migrated.decorationPlacements == nil, "Old habitats keep their progress and original layout")
        print("Decoration checks passed: placement, bounds, locks, persistence, old saves, and preview isolation.")
    }

    static func checkExpandedShop() throws {
        let defaults = MemoryDefaults(suiteName: "Recycli.ShopChecks")!
        defaults.set(try JSONEncoder().encode(HabitatState(points: 400)), forKey: "ecogotchi.habitat.v1")
        let store = HabitatStore(defaults: defaults)
        store.stockPreviewFood()
        store.setPreviewFoodCount("berries", count: 5)
        precondition(store.state.foodInventory == nil, "Food developer controls do nothing to a real game")
        store.selectFood("berries")
        precondition(store.selectedFood == nil)
        precondition(store.buyFood("berries"))
        store.selectFood("berries")
        precondition(store.selectedFood?.id == "berries" && store.feedPet("pip"))
        precondition(store.selectedFood == nil && !store.feedPet("pip"), "Consuming the last snack ends feeding mode")
        let savedMeals = HabitatStore(defaults: defaults).state.petMeals
        precondition(savedMeals?["pip"] == 1)
        precondition(store.buyFood("crunch"))
        store.selectFood("crunch")
        store.selectHabitat(.ocean)
        precondition(store.selectedFood == nil && store.state.habitat == .ocean)
        precondition(HabitatStore(defaults: defaults).state.habitat == .ocean, "The selected habitat survives relaunch")
        store.selectFood("berries")
        precondition(store.selectedFood == nil, "A snack from the wrong habitat cannot be armed")
        let live = store.state
        store.beginDeveloperMode()
        store.unlockPreview()
        store.selectFood("kelp")
        precondition(store.feedPet("bubbles"))
        store.setLitter(6)
        precondition(!store.feedPet("inky"), "Sheltering pets cannot consume food in normal visibility")
        store.developer.ignoreRetreat = true
        precondition(store.feedPet("inky"), "The developer shelter override also supports feeding the visible pets")
        store.setLitter(0)
        store.selectHabitat(.snow)
        store.setActionCount(3)
        precondition(store.state.unlockedAnimals.count == 3)
        store.selectHabitat(.ocean)
        precondition(store.state.habitatActionCount == 6, "Editing another habitat's actions preserves this one's progress")
        store.setActionCount(1)
        store.selectHabitat(.snow)
        precondition(store.state.habitatActionCount == 3, "Trimming preview actions only trims the selected habitat")
        let reloaded = HabitatStore(defaults: defaults)
        precondition(reloaded.state.habitat == live.habitat && reloaded.state.points == live.points)
        precondition(reloaded.state.foodInventory == live.foodInventory && reloaded.state.petMeals == live.petMeals)
        precondition(reloaded.state.actions.count == live.actions.count, "Preview visits, purchases, feeding, and unlocks never persist")
        store.endDeveloperMode()
        precondition(store.state.habitat == live.habitat && store.state.foodInventory == live.foodInventory && store.selectedFood == nil)
        print("Shop store checks passed: purchases, feeding selection, habitat persistence, and developer preview isolation.")
    }

    static func main() throws {
        checkDemoRewards()
        checkActualPreview()
        try checkDecorationLayouts()
        try checkExpandedShop()
        let defaults = MemoryDefaults(suiteName: "Recycli.InMemoryChecks")!
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

    static func checkActualPreview() {
        let defaults = MemoryDefaults(suiteName: "Recycli.ActualPreview")!
        let store = HabitatStore(defaults: defaults)
        let original = store.state
        let assessment = review()
        precondition(!store.recordPreviewReviewedAction(assessment), "Preview receipts never mutate a live habitat")
        store.beginDeveloperMode()
        precondition(!store.recordPreviewReviewedAction(assessment), "Demo mode cannot claim Actual review rewards")
        store.recyclingMode = .ai
        store.developer.actionReward = 100
        store.developer.cleanupPerAction = 6
        precondition(store.recordPreviewReviewedAction(assessment))
        precondition(store.state.points == original.points + 30 && store.state.litter == original.litter - 1,
                     "Actual preview rewards follow the material policy, not simulated reward controls")
        precondition(store.state.actions.last?.item.hasPrefix("[Preview]") == true)
        precondition(!store.recordPreviewReviewedAction(assessment), "An Actual preview receipt cannot award twice")
        precondition(!store.recordPreviewReviewedAction(review(status: .rejected)), "Rejected Actual reviews never earn preview leaves")
        let reopened = HabitatStore(defaults: defaults)
        precondition(reopened.state.points == original.points && reopened.state.actions.count == original.actions.count,
                     "Actual preview rewards never overwrite the real save")
        precondition(reopened.recyclingMode == .demo, "Preview scan preferences never overwrite the saved mode")
        store.endDeveloperMode()
        precondition(store.recyclingMode == .demo && store.state.points == original.points)
        store.recyclingMode = .ai
        precondition(HabitatStore(defaults: defaults).recyclingMode == .ai, "Actual mode selected outside preview persists")
        precondition(store.recordReviewedAction(review()), "Actual reviews can reward the live game after leaving preview")
        print("Actual preview checks passed: preference restoration, real review policy, deduplication, and saved-game isolation.")
    }

    static func checkDemoRewards() {
        let defaults = MemoryDefaults(suiteName: "Recycli.DemoChecks")!
        let store = HabitatStore(defaults: defaults)
        precondition(store.isDemoRecycling, "The hackathon build starts in offline demo mode")
        let frames = ["bin", "item"].map {
            RecyclingPhoto(role: $0, source: "camera", mimeType: "image/jpeg", capturedAt: "2026-10-10T12:00:00Z", data: "demo-photo")
        }
        let submission = RecyclingSubmission(submissionId: UUID(), photos: frames)
        precondition(!store.recordDemoAction(.init(submissionId: UUID(), photos: Array(frames.prefix(1)))), "Incomplete scans cannot award")
        precondition(!store.recordDemoAction(.init(submissionId: UUID(), photos: Array(frames.reversed()))), "Item-first scans cannot award")
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
              explanation: "Can matches the bin’s sorting instructions", tip: "Follow this bin’s instructions.", labelEvidence: "Empty cans",
              evidenceQuality: quality, verification: verification, limitation: "Visual review only")
    }
}
