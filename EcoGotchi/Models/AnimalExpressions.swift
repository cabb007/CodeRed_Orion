import Foundation
import CoreGraphics

enum AnimalExpressions {
    static let dropSounds = ["pip":"Peep!", "fern":"Ribbit!", "clover":"Squeak!", "maple":"Yip!",
        "bubbles":"Blub!", "shelly":"Hiss!", "inky":"Bloop!", "fin":"Click-click!",
        "waddles":"Honk!", "flurry":"Yip-yip!", "pebble":"Arf!", "snowdrop":"Squeak-squeak!"]
    private struct Row {
        let y: CGFloat
        let height: CGFloat
        let width: CGFloat
        let centers: [CGFloat]
    }
    private static let frames: [HabitatKind: [Row]] = [
        .grove: [.init(y:70,height:270,width:244,centers:[160.5,474.5,777.5,1085]),
            .init(y:359,height:276,width:269,centers:[181,495.5,801.5,1107.5]),
            .init(y:634,height:297,width:227,centers:[169,483,790,1099.5]),
            .init(y:933,height:279,width:291,centers:[183,497.5,805.5,1110.5])],
        .ocean: [.init(y:70,height:216,width:277,centers:[161,475,788,1101.5]),
            .init(y:362,height:221,width:301,centers:[157,471,784,1097.5]),
            .init(y:640,height:264,width:289,centers:[165,478.5,792.5,1105.5]),
            .init(y:953,height:248,width:292,centers:[168.5,481,794.5,1108])],
        .snow: [.init(y:72,height:258,width:279,centers:[163,473.5,782.5,1091.5]),
            .init(y:359,height:281,width:292,centers:[155.5,466.5,776,1086.5]),
            .init(y:680,height:224,width:302,centers:[158,469.5,775.5,1085]),
            .init(y:917,height:302,width:259,centers:[151.5,464,775.5,1085.5])]
    ]
    static func frame(animalID: String, condition: HabitatCondition) -> (asset: String, rect: CGRect)? {
        guard let animal = HabitatAnimal.all.first(where: { $0.id == animalID }),
              let rowIndex = animal.habitat.animals.firstIndex(where: { $0.id == animalID }),
              let rows = frames[animal.habitat],
              let column = HabitatCondition.allCases.firstIndex(of: condition) else { return nil }
        let row = rows[rowIndex]
        let x = max(0, min(1254 - row.width, row.centers[column] - row.width / 2))
        let names: [HabitatKind: String] = [.grove:"GroveExpressions", .ocean:"OceanExpressions", .snow:"SnowExpressions"]
        return (names[animal.habitat]!, CGRect(x:x/1254,y:row.y/1254,width:row.width/1254,height:row.height/1254))
    }
}
