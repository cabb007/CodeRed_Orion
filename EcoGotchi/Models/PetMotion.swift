import Foundation
import CoreGraphics

// Keep play inside the visible habitat, including after a fast flick or a resize.
enum PetMotion {
    static func bounded(_ point: CGPoint, in playground: CGRect, size: CGFloat) -> CGPoint {
        let margin = max(0, size) * 0.65
        let insetX = min(margin, playground.width / 2)
        let insetY = min(margin, playground.height / 2)
        return CGPoint(x: min(playground.maxX - insetX, max(playground.minX + insetX, point.x)),
                       y: min(playground.maxY - insetY, max(playground.minY + insetY, point.y)))
    }

    static func bounds(in playground: CGRect, size: CGFloat, groundY: CGFloat) -> CGRect {
        let topLeft = bounded(CGPoint(x: playground.minX, y: playground.minY), in: playground, size: size)
        let bottomRight = bounded(CGPoint(x: playground.maxX, y: groundY), in: playground, size: size)
        return CGRect(x: topLeft.x, y: topLeft.y, width: max(0, bottomRight.x - topLeft.x),
                      height: max(0, bottomRight.y - topLeft.y))
    }

    static func swing(horizontalMovement: CGFloat) -> Double {
        Double(max(-28, min(28, horizontalMovement * 1.8)))
    }
}

// Positions are sprite centers. The bottom of these bounds is each pet's ground lane.
// Small integration steps keep a fast throw from tunneling through the floor.
struct PetBody: Equatable {
    var position: CGPoint
    private(set) var velocity = CGVector.zero
    private(set) var isGrounded = true

    mutating func settle(in bounds: CGRect) {
        position = CGPoint(x: min(bounds.maxX, max(bounds.minX, position.x)), y: bounds.maxY)
        velocity = .zero
        isGrounded = true
    }

    mutating func drop(from point: CGPoint, predictedTravel: CGSize, in bounds: CGRect) {
        position = CGPoint(x: min(bounds.maxX, max(bounds.minX, point.x)),
                           y: min(bounds.maxY, max(bounds.minY, point.y)))
        velocity = CGVector(dx: max(-320, min(320, predictedTravel.width * 2)),
                            dy: max(-420, min(420, predictedTravel.height * 2)))
        isGrounded = false
    }

    @discardableResult
    mutating func advance(seconds: TimeInterval, in bounds: CGRect, gravity: CGFloat = 1_450) -> Bool {
        guard !isGrounded, seconds.isFinite, seconds > 0 else { return false }
        // Ignore long pauses (backgrounding, debugger) rather than teleporting across the scene.
        var remaining = min(seconds, 0.1)
        while remaining > 0, !isGrounded {
            let step = min(remaining, 1.0 / 120)
            remaining -= step
            let dt = CGFloat(step)
            velocity.dy += gravity * dt
            velocity.dx *= exp(-1.4 * dt)
            position.x += velocity.dx * dt
            position.y += velocity.dy * dt
            if position.x < bounds.minX || position.x > bounds.maxX {
                position.x = min(bounds.maxX, max(bounds.minX, position.x))
                velocity.dx *= -0.3
            }
            if position.y < bounds.minY {
                position.y = bounds.minY
                velocity.dy = max(0, velocity.dy)
            }
            if position.y >= bounds.maxY {
                position.y = bounds.maxY
                if velocity.dy > 100 {
                    velocity.dy *= -0.24
                    velocity.dx *= 0.55
                } else {
                    settle(in: bounds)
                }
            }
        }
        return isGrounded
    }

    @discardableResult
    mutating func walk(toward target: CGFloat, speed: CGFloat, seconds: TimeInterval, in bounds: CGRect) -> Bool {
        guard isGrounded, seconds.isFinite, seconds > 0, target.isFinite else { return false }
        let destination = min(bounds.maxX, max(bounds.minX, target))
        let distance = destination - position.x
        let step = max(0, speed) * CGFloat(min(seconds, 0.1))
        position.x += max(-step, min(step, distance))
        settle(in: bounds)
        return abs(destination - position.x) < 0.5
    }
}
