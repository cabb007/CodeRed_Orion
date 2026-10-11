import Foundation

@main
struct HabitatExpansionChecks {
    static func main() throws {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let habitats = HabitatKind.allCases
        for (index, habitat) in habitats.enumerated() {
            precondition(habitat.previous == (index > 0 ? habitats[index - 1] : nil))
            precondition(habitat.next == (index + 1 < habitats.count ? habitats[index + 1] : nil))
            if let next = habitat.next { precondition(next.previous == habitat) }
            if let previous = habitat.previous { precondition(previous.next == habitat) }
        }
        precondition(HabitatAnimal.all.count == 12 && Set(HabitatAnimal.all.map(\.id)).count == 12)
        precondition(Decoration.all.count == 12 && Set(Decoration.all.map(\.id)).count == 12)
        for habitat in HabitatKind.allCases {
            precondition(habitat.animals.count == 4 && habitat.animals.first?.id == habitat.starterID)
            precondition(habitat.animals.map(\.requiredActions) == [0, 1, 3, 6])
            precondition(habitat.decorations.count >= 3 && habitat.foods.count >= 2)
        }
        var state = HabitatState(points: 400, litter: 1, lastPollution: start)
        state.recordAction(item: "Legacy can", at: start)
        precondition(state.habitat == .grove && state.habitatActionCount == 1 && state.unlockedAnimals.count == 2)
        precondition(state.purchase(Decoration.all[0]))
        state.moveDecoration("flowers", x: 0.3, y: 0.7)
        state.setDecorationLocked("flowers", locked: true)
        let groveLayout = state.placement(for: "flowers")
        let groveLitter = state.litter
        state.selectHabitat(.ocean, at: start)
        precondition(state.habitat == .ocean && state.litter == 3 && state.habitatActionCount == 0)
        precondition(state.unlockedAnimals.map(\.id) == ["bubbles"], "A new habitat starts with its own starter pet")
        precondition(!state.purchase(Decoration.all.first { $0.id == "bench" }!), "Shop cannot buy another habitat's decor")
        precondition(!state.moveDecoration("flowers", x: 1, y: 1), "Other habitats' layouts cannot be moved here")
        precondition(!state.setDecorationLocked("flowers", locked: false))
        precondition(state.purchase(Decoration.all.first { $0.id == "coral" }!))
        state.moveDecoration("coral", x: 0.6, y: 0.8)
        state.setDecorationLocked("coral", locked: true)
        state.resetDecorationLayout()
        precondition(state.placement(for: "coral").x == nil && state.placement(for: "flowers") == groveLayout, "Layout reset only affects the current habitat")
        for _ in 0..<3 { state.recordAction(item: "Reef cleanup", at: start) }
        precondition(state.unlockedAnimals.map(\.id) == ["bubbles", "shelly", "inky"])
        precondition(state.actions.last?.habitatID == "ocean" && state.litter == 0)
        state.selectHabitat(.grove, at: start)
        precondition(state.litter == groveLitter && state.habitatActionCount == 1 && state.placement(for: "flowers") == groveLayout)
        state.selectHabitat(.snow, at: start)
        precondition(state.unlockedAnimals.map(\.id) == ["waddles"] && state.habitatActionCount == 0)
        state.selectHabitat(.ocean, at: start.addingTimeInterval(14_400))
        state.advance(to: start.addingTimeInterval(14_400))
        precondition(state.litter == 1 && state.habitatActionCount == 3, "Away-time pollution and pet progress restore per habitat")
        state.advance(to: start.addingTimeInterval(14_400))
        precondition(state.litter == 1, "Revisiting cannot apply pollution twice")
        state.litter = 6
        precondition(state.residentAnimals.map(\.id) == ["bubbles"], "Each polluted habitat retains its own starter")

        var feeding = HabitatState(points: 20, litter: 3, lastPollution: start)
        precondition(!feeding.buyFood("kelp") && !feeding.buyFood("made-up"))
        precondition(feeding.buyFood("berries") && feeding.points == 15 && feeding.foodCount("berries") == 1)
        let beforeFeeding = feeding
        precondition(!feeding.feed("fern", foodID: "berries"), "Locked pets cannot consume food")
        precondition(!feeding.feed("bubbles", foodID: "berries"), "Pets from another habitat cannot consume food")
        precondition(feeding.foodCount("berries") == 1 && feeding.points == beforeFeeding.points)
        precondition(feeding.feed("pip", foodID: "berries"))
        precondition(feeding.foodCount("berries") == 0 && feeding.petMeals?["pip"] == 1)
        precondition(feeding.points == beforeFeeding.points && feeding.litter == beforeFeeding.litter && feeding.actions.isEmpty, "Feeding grants affection, not recycling rewards or cleanup")
        precondition(!feeding.feed("pip", foodID: "berries"), "One snack cannot be spent twice")
        feeding.foodInventory?["berries"] = 99
        precondition(!feeding.buyFood("berries") && feeding.points == 15, "A full bag does not charge leaves")
        feeding.foodInventory?["berries"] = -50
        precondition(feeding.foodCount("berries") == 0 && !feeding.feed("pip", foodID: "berries"))
        feeding.points = 0
        precondition(!feeding.buyFood("apple"), "Food cannot overdraft the wallet")
        feeding.points = 20
        feeding.selectHabitat(.ocean, at: start)
        precondition(feeding.buyFood("kelp") && feeding.feed("bubbles", foodID: "kelp"))
        let restored = try JSONDecoder().decode(HabitatState.self, from: JSONEncoder().encode(feeding))
        precondition(restored.habitat == .ocean && restored.petMeals?["bubbles"] == 1 && restored.foodCount("kelp") == 0)

        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(beforeFeeding)) as! [String: Any]
        for field in ["habitatID", "otherHabitats", "foodInventory", "petMeals"] { old.removeValue(forKey: field) }
        var oldActions = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Array(state.actions.prefix(1)))) as! [[String: Any]]
        oldActions[0].removeValue(forKey: "habitatID")
        old["actions"] = oldActions
        let migrated = try JSONDecoder().decode(HabitatState.self, from: JSONSerialization.data(withJSONObject: old))
        precondition(migrated.habitat == .grove && migrated.habitatActionCount == 1 && migrated.points == 15)
        precondition(migrated.petMeals == nil && migrated.foodInventory == nil, "Old saves migrate without resetting progress")
        print("Habitat expansion checks passed: catalog, independent habitats, away-time pollution, pet unlocks, layouts, food economy, feeding, persistence, and migration.")
    }
}
