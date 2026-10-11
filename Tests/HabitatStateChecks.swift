import Foundation

@main
struct HabitatStateChecks {
    static func main() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var state = HabitatState(lastPollution: start)
        state.advance(to: start.addingTimeInterval(14_399))
        precondition(state.litter == 3, "No pollution before four hours")
        state.advance(to: start.addingTimeInterval(14_400))
        precondition(state.litter == 4, "One piece arrives at four hours")
        state.advance(to: start.addingTimeInterval(14_400))
        precondition(state.litter == 4, "Refreshing cannot double count an interval")
        state.advance(to: start.addingTimeInterval(1_000_000))
        precondition(state.litter == 6 && state.health == 10, "Offline pollution is capped")
        state.advance(to: start)
        precondition(state.litter == 6, "Clock rollback does not add pollution")
        precondition(!state.purchase(Decoration.all[0]), "Cannot spend leaves not earned")
        state.recordAction(item: "Aluminum can", at: start)
        precondition(state.points == 20 && state.litter == 5, "Action awards leaves and removes litter")
        precondition(state.unlockedAnimals.map(\.id) == ["pip", "fern"], "First action unlocks Fern")
        state.recordAction(item: "Paper", at: start)
        precondition(state.purchase(Decoration.all[0]), "Earned leaves can buy a decoration")
        precondition(state.points == 0 && state.ownedDecorations.contains("flowers"), "Purchase is applied")
        precondition(!state.purchase(Decoration.all[0]), "Cannot buy a decoration twice")
        for _ in 0..<8 { state.recordAction(item: "Cardboard", at: start) }
        precondition(state.litter == 0 && state.health == 100, "Restoration never creates negative litter")
        precondition(state.unlockedAnimals.count == 4 && state.nextAnimal == nil, "All animal milestones unlock")
        let saved = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(HabitatState.self, from: saved)
        precondition(restored.actions.count == 10 && restored.points == 160 && restored.ownedDecorations == ["flowers"], "Progress survives a save and reload")
        // Every pollution boundary selects the intended visual state.
        let conditions: [HabitatCondition] = [.thriving, .littered, .littered, .tarnished, .tarnished, .polluted, .polluted]
        for (litter, expected) in conditions.enumerated() {
            state.litter = litter
            precondition(state.condition == expected, "Wrong condition for \(litter) litter")
            precondition(state.cleanedPercent == [100, 83, 67, 50, 33, 17, 0][litter], "Cleaned percentage must span the full litter capacity")
            precondition((0...1).contains(state.cleanedFraction))
        }
        precondition(state.residentAnimals.count == 1 && state.unlockedAnimals.count == 4, "Pollution makes animals shelter without deleting collection")
        state.litter = 4
        precondition(state.residentAnimals.count == 4, "Animals return when the habitat recovers")
        state.litter = -1
        precondition(state.cleanedFraction == 1 && state.cleanedPercent == 100)
        state.litter = 7
        precondition(state.cleanedFraction == 0 && state.cleanedPercent == 0, "Progress rendering stays within the bar for invalid legacy values")

        var timing = HabitatState(litter: 0, lastPollution: start)
        timing.advance(to: start.addingTimeInterval(21_600))
        precondition(timing.litter == 1 && timing.lastPollution == start.addingTimeInterval(14_400), "Partial pollution interval is preserved")
        timing.advance(to: start.addingTimeInterval(28_800))
        precondition(timing.litter == 2, "Next drop still occurs on schedule")
        timing.advance(to: start.addingTimeInterval(28_805), interval: 5)
        precondition(timing.litter == 3, "Accelerated developer clock advances pollution")
        timing.recordAction(item: "Preview", reward: 35, cleanup: 2)
        precondition(timing.points == 35 && timing.litter == 1 && timing.actions.last?.reward == 35, "Custom cleanup and rewards agree with the journal")
        timing.advance(to: start.addingTimeInterval(30_000), interval: 0)
        precondition(timing.litter == 1, "Invalid timing interval is ignored")

        // Existing saves have no reward field; they must continue to decode.
        var legacy = try JSONSerialization.jsonObject(with: saved) as! [String: Any]
        var actions = legacy["actions"] as! [[String: Any]]
        for index in actions.indices { actions[index].removeValue(forKey: "leavesEarned") }
        legacy["actions"] = actions
        let migrated = try JSONDecoder().decode(HabitatState.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(migrated.actions.count == 10 && migrated.actions.first?.reward == 20, "Old saves preserve progress and default rewards")

        var session = HabitatSession(state: restored)
        session.beginPreview()
        session.state.points = 9_999
        session.state.actions.removeAll()
        session.beginPreview()
        precondition(session.persistedState.points == restored.points && session.persistedState.actions.count == 10, "Reopening developer mode cannot overwrite its snapshot")
        session.endPreview()
        precondition(!session.isDeveloperMode && session.state.points == restored.points && session.state.actions.count == 10, "Exiting restores original progress")
        print("Habitat checks passed: state boundaries, timing, cleanup, rewards, purchases, legacy saves, and preview restoration.")
    }
}
