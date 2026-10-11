import Foundation
import CoreGraphics
import Combine

// All residents share one collision world. Corrections keep each body's height,
// so a landed animal never becomes stuck above its ground lane.
@MainActor
final class AnimalWorld: ObservableObject {
    struct Entry {
        var body: PetBody
        let bounds: CGRect
        let size: CGFloat
        var half: CGFloat { size * 0.78 }
        var halfY: CGFloat { size * 0.78 + 8 }
    }
    @Published private(set) var residents: [String: Entry] = [:]
    static let capacity = 4
    func body(for id: String) -> PetBody? { residents[id]?.body }
    func remove(_ id: String) { residents.removeValue(forKey: id) }

    @discardableResult
    func move(_ id: String, body: PetBody, bounds: CGRect, size: CGFloat) -> PetBody {
        guard residents[id] != nil || residents.count < Self.capacity else { return body }
        var entry = Entry(body:body, bounds:bounds, size:size)
        var next = residents
        let others = next.filter { $0.key != id }
        let free: (CGFloat) -> Bool = { x in
            others.values.allSatisfy { other in
                abs(x - other.body.position.x) >= entry.half + other.half + 2 ||
                    abs(entry.body.position.y - other.body.position.y) >= entry.halfY + other.halfY + 2
            }
        }
        if !free(body.position.x) {
            var candidates = [body.position.x, bounds.minX, bounds.maxX]
            for other in others.values {
                let gap = entry.half + other.half + 2.01
                candidates += [other.body.position.x - gap, other.body.position.x + gap]
            }
            if let x = candidates.filter({ bounds.minX...bounds.maxX ~= $0 && free($0) })
                .min(by: { abs($0-body.position.x) < abs($1-body.position.x) }) {
                entry.body.shiftHorizontally(to:x)
            } else {
                next[id] = entry
                let group = next.sorted { a,b in
                    a.value.body.position.x == b.value.body.position.x ? a.key < b.key :
                        a.value.body.position.x < b.value.body.position.x
                }
                var edge = -CGFloat.infinity
                var packed: [(String, Entry, CGFloat)] = []
                for (key,item) in group {
                    let x = max(item.bounds.minX, edge + item.half + 2.01)
                    packed.append((key,item,x))
                    edge = x + item.half
                }
                if packed.allSatisfy({ $0.2 <= $0.1.bounds.maxX }) {
                    let shift = max(0, packed.map { $0.1.bounds.maxX - $0.2 }.min()! / 2)
                    for (key,savedItem,x) in packed {
                        var item = savedItem
                        item.body.shiftHorizontally(to:x+shift)
                        next[key] = item
                        if key == id { entry = item }
                    }
                }
            }
        }
        next[id] = entry
        residents = next
        return entry.body
    }
}
