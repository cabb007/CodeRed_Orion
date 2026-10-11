import Foundation
import CoreGraphics

@main
struct PetMotionChecks {
    static func main() {
        let field = CGRect(x: 20, y: 240, width: 350, height: 430)
        let center = CGPoint(x: 195, y: 455)
        precondition(PetMotion.bounded(center, in: field, size: 60) == center)
        for point in [CGPoint(x: -10_000, y: -10_000), CGPoint(x: 10_000, y: 10_000),
                      CGPoint(x: 10_000, y: -10_000), CGPoint(x: -10_000, y: 10_000)] {
            let clamped = PetMotion.bounded(point, in: field, size: 60)
            precondition(field.insetBy(dx: 38, dy: 38).contains(clamped), "A dragged pet stays reachable")
        }
        let tiny = CGRect(x: 10, y: 20, width: 30, height: 40)
        precondition(PetMotion.bounded(CGPoint(x: 500, y: -500), in: tiny, size: 150) == CGPoint(x: tiny.midX, y: tiny.midY), "Oversized sprites center safely in small play areas")
        precondition(PetMotion.swing(horizontalMovement: 0) == 0)
        precondition(PetMotion.swing(horizontalMovement: 1_000) == 28)
        precondition(PetMotion.swing(horizontalMovement: -1_000) == -28)

        let bounds = PetMotion.bounds(in: field, size: 60, groundY: 600)
        precondition(bounds.maxY == 600 && bounds.minX == 59)
        for travel in [CGSize.zero, CGSize(width: -10_000, height: -10_000), CGSize(width: 10_000, height: 10_000)] {
            var pet = PetBody(position: center)
            pet.drop(from: center, predictedTravel: travel, in: bounds)
            precondition(abs(pet.velocity.dx) <= 320 && abs(pet.velocity.dy) <= 420, "Throw speed is capped")
            let paused = pet
            pet.advance(seconds: .nan, in: bounds)
            pet.advance(seconds: -1, in: bounds)
            precondition(pet == paused, "Invalid time steps do nothing")
            var landingCount = 0
            for _ in 0..<240 {
                if pet.advance(seconds: 1.0 / 60, in: bounds) { landingCount += 1 }
                precondition(pet.position.x >= bounds.minX && pet.position.x <= bounds.maxX)
                precondition(pet.position.y >= bounds.minY && pet.position.y <= bounds.maxY, "Gravity cannot escape the play area")
            }
            precondition(pet.isGrounded && pet.position.y == bounds.maxY && pet.velocity == .zero, "Drops and throws settle onto the grass")
            precondition(landingCount == 1, "A drop lands once without endless bouncing or haptics")
        }

        var falling = PetBody(position: center)
        falling.drop(from: center, predictedTravel: .zero, in: bounds)
        falling.advance(seconds: 1.0 / 30, in: bounds)
        precondition(falling.position.y > center.y && falling.position.y < bounds.maxY, "Drops fall progressively instead of teleporting")
        let beforeWalk = falling
        falling.walk(toward: bounds.minX, speed: 21, seconds: 0.1, in: bounds)
        precondition(falling == beforeWalk, "Autonomous walking cannot override a fall")
        var longPause = beforeWalk
        var shortPause = beforeWalk
        longPause.advance(seconds: 300, in: bounds)
        shortPause.advance(seconds: 0.1, in: bounds)
        precondition(longPause == shortPause, "A debugger or background pause cannot produce a huge jump")
        var seaPet = PetBody(position: center)
        var landPet = PetBody(position: center)
        seaPet.drop(from: center, predictedTravel: .zero, in: bounds)
        landPet.drop(from: center, predictedTravel: .zero, in: bounds)
        for _ in 0..<60 {
            seaPet.advance(seconds: 1.0 / 60, in: bounds, gravity: 220)
            landPet.advance(seconds: 1.0 / 60, in: bounds)
        }
        precondition(seaPet.position.y < landPet.position.y, "Ocean pets drift down more slowly than land pets")
        for _ in 0..<300 { seaPet.advance(seconds: 1.0 / 60, in: bounds, gravity: 220) }
        precondition(seaPet.isGrounded, "An ocean drop settles back into its swimming lane")
        falling.settle(in: bounds)
        for destination in [-10_000.0, 10_000.0] {
            var arrived = false
            for _ in 0..<240 {
                arrived = falling.walk(toward: destination, speed: 27, seconds: 0.1, in: bounds)
                precondition(falling.position.y == bounds.maxY && falling.isGrounded)
            }
            precondition(arrived && falling.position.x == (destination < 0 ? bounds.minX : bounds.maxX), "Roaming stays on the ground and stops at the edge")
        }
        let tinyBounds = PetMotion.bounds(in: tiny, size: 150, groundY: 500)
        falling.drop(from: .zero, predictedTravel: CGSize(width: 900, height: -900), in: tinyBounds)
        for _ in 0..<120 { falling.advance(seconds: 1.0 / 30, in: tinyBounds) }
        precondition(falling.position == CGPoint(x: tiny.midX, y: tiny.midY) && falling.isGrounded)
        print("Pet motion checks passed: roaming, gravity, bounded throws, stable landings, pause handling, and oversized sprites.")
    }
}
