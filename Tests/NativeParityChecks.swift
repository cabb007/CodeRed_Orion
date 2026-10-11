import Foundation
import CoreGraphics

@main
@MainActor
struct NativeParityChecks {
    static func main() throws {
        let suite = "EcoGotchi.Parity.\(UUID())"
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        defaults.set("ai",forKey:"ecogotchi.recyclingMode")
        defaults.set(false,forKey:"ecogotchi.scanSounds")
        let game = HabitatStore(defaults:defaults)
        let realMode = game.recyclingMode
        let oldID = game.modeSessionID
        game.beginDeveloperMode()
        precondition(game.isDemoRecycling)
        game.scanSounds = true
        game.setPoints(500)
        game.stockPreviewFood()
        game.selectHabitat(.ocean)
        precondition(defaults.object(forKey:"ecogotchi.scanSounds") as? Bool == false)
        precondition(defaults.string(forKey:"ecogotchi.recyclingMode") == realMode.rawValue)
        game.endDeveloperMode()
        precondition(game.recyclingMode == realMode && !game.scanSounds)
        precondition(game.state.habitat == .grove && game.state.points == 0)
        precondition(game.state.foodInventory == nil)
        precondition(!game.isCurrentSession(oldID))
        game.beginDeveloperMode()
        game.record(item:"Stale callback",sessionID:oldID)
        precondition(game.state.actions.isEmpty)
        game.endDeveloperMode()

        for animal in HabitatAnimal.all {
            precondition(AnimalExpressions.dropSounds[animal.id] != nil)
            for condition in HabitatCondition.allCases {
                let frame = AnimalExpressions.frame(animalID:animal.id,condition:condition)!
                precondition(CGRect(x:0,y:0,width:1,height:1).contains(frame.rect))
            }
        }
        let world = AnimalWorld()
        let bounds = CGRect(x:20,y:10,width:360,height:180)
        for index in 0..<4 {
            var body = PetBody(position:CGPoint(x:200,y:190))
            body.settle(in:bounds)
            world.move("animal-\(index)",body:body,bounds:bounds,size:45)
        }
        precondition(world.residents.count == 4)
        world.move("fifth",body:PetBody(position:.zero),bounds:bounds,size:45)
        precondition(world.residents.count == 4)
        let residents = Array(world.residents.values)
        for i in residents.indices {
            precondition(residents[i].body.isGrounded && residents[i].body.position.y == bounds.maxY)
            for j in residents.indices where j > i {
                precondition(abs(residents[i].body.position.x-residents[j].body.position.x) >=
                    residents[i].half + residents[j].half + 2)
            }
        }
        var dropping = PetBody(position:CGPoint(x:200,y:30))
        dropping.drop(from:dropping.position,predictedTravel:.zero,in:bounds)
        for _ in 0..<300 {
            dropping.advance(seconds:0.033,in:bounds)
            dropping = world.move("animal-0",body:dropping,bounds:bounds,size:45)
        }
        precondition(dropping.isGrounded && dropping.position.y == bounds.maxY)
        dropping.walk(toward:bounds.maxX,speed:21,seconds:0.1,in:bounds)
        precondition(dropping.isGrounded)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("EcoGotchi-Parity-\(UUID())")
        defer { try? FileManager.default.removeItem(at:directory) }
        let file = directory.appendingPathComponent("bins.json")
        let bins = CommunityBinStore(fileURL:file)
        let photo = BinPhoto(data:Data([0xff,0xd8,0xff,0xd9]).base64EncodedString(),
                             source:"camera",capturedAt:ISO8601DateFormatter().string(from:Date()))
        let draft = BinDraft(name:" Library bin ",notes:" Outside ",coordinate:.init(latitude:29.123456,longitude:-95.123456),
                             materials:["Paper","Paper"],publicAccess:true,photo:photo)
        try bins.save(draft,game:game,sessionID:game.modeSessionID)
        precondition(bins.saved.count == 1 && bins.saved[0].draft.name == "Library bin")
        precondition(bins.saved[0].draft.coordinate.latitude == 29.12346)
        precondition(bins.saved[0].draft.materials == ["Paper"])
        precondition(game.state.points == 0 && game.state.actions.isEmpty)
        precondition(CommunityBinStore(fileURL:file).saved == bins.saved)
        try bins.save(draft,game:game,sessionID:game.modeSessionID)
        precondition(bins.saved.count == 1)
        game.beginDeveloperMode()
        do { try bins.removePhone(draft.id,game:game,sessionID:game.modeSessionID); preconditionFailure("Preview removed a real landmark") }
        catch { }
        precondition(bins.saved.count == 1)
        game.endDeveloperMode()
        do { try bins.removePhone(draft.id,game:game,sessionID:oldID); preconditionFailure("Stale callback removed a landmark") }
        catch { }
        var invalid = draft
        invalid.publicAccess = false
        do { _ = try invalid.validated(); preconditionFailure("Private bin accepted") } catch { }
        invalid = draft; invalid.materials = ["Unsupported"]
        do { _ = try invalid.validated(); preconditionFailure("Unsupported materials accepted") } catch { }
        try bins.removePhone(draft.id,game:game,sessionID:game.modeSessionID)
        precondition(bins.saved.isEmpty && CommunityBinStore(fileURL:file).saved.isEmpty)
        try Data("broken save".utf8).write(to:file)
        let broken = CommunityBinStore(fileURL:file)
        do { try broken.save(draft,game:game,sessionID:game.modeSessionID); preconditionFailure("Corrupt save overwritten") } catch { }
        let kept = try String(contentsOf:file,encoding:.utf8)
        precondition(kept == "broken save")
        print("Native parity checks passed")
    }
}
