import SwiftUI

/// Keeps scenery ticks isolated from the draggable pets and decorations.
struct HabitatAtmosphere: View {
    let habitat: HabitatKind
    let condition: HabitatCondition
    let litter: Int
    let animate: Bool
    let sceneActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsed = 0.0
    @State private var startedAt: Date?
    @State private var restoredAt: Double?
    @State private var pendingRestoration = false

    private var running: Bool { animate && sceneActive && scenePhase == .active && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !running)) { timeline in
            let time = elapsed + (startedAt.map { max(0, timeline.date.timeIntervalSince($0)) } ?? 0)
            HabitatAtmosphereFrame(habitat: habitat, condition: condition, time: time,
                                   restoration: reduceMotion ? nil : restoredAt.map { (time - $0) / 2.4 })
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .onAppear { updateClock() }
        .onChange(of: running) { _, _ in updateClock() }
        .onChange(of: litter) { previous, current in
            guard current < previous, animate, !reduceMotion else { return }
            pendingRestoration = true
            if running { beginRestoration() }
        }
        .onDisappear { pauseClock() }
    }

    private func updateClock() {
        pauseClock()
        if running {
            startedAt = Date()
            if pendingRestoration { beginRestoration() }
        } else if reduceMotion || !animate {
            restoredAt = nil
            pendingRestoration = false
        }
    }

    private func pauseClock() {
        if let startedAt { elapsed += max(0, Date().timeIntervalSince(startedAt)) }
        startedAt = nil
    }

    private func beginRestoration() {
        restoredAt = elapsed + (startedAt.map { max(0, Date().timeIntervalSince($0)) } ?? 0)
        pendingRestoration = false
    }
}

/// A 180 × 320 logical pixel grid matches the backgrounds without blurring edges.
struct HabitatAtmosphereFrame: View {
    let habitat: HabitatKind
    let condition: HabitatCondition
    let time: Double
    var restoration: Double? = nil

    private var damage: Double {
        switch condition { case .thriving: 0; case .littered: 0.18; case .tarnished: 0.55; case .polluted: 1 }
    }
    private var vitality: Double { 1 - damage }

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 180, y: size.height / 320)
            switch habitat {
            case .grove: grove(&context)
            case .ocean: ocean(&context)
            case .snow: snow(&context)
            }
            if damage > 0.3 { haze(&context) }
            if let restoration, (0..<1).contains(restoration) { recovery(&context, progress: restoration) }
        }
    }

    private func grove(_ context: inout GraphicsContext) {
        light(&context, underwater: false)

        // Expanding stepped rings stay inside the pond painted into the grove scene.
        for index in 0..<3 {
            let p = cycle(time / (6 + damage * 5) + Double(index) / 3)
            ring(&context, x: 132 + Double(index) * 7, y: 175 + Double(index) * 4,
                 width: 4 + p * 22, height: 1 + p * 4,
                 color: (damage > 0.5 ? Color(red: 0.74, green: 0.71, blue: 0.44) : Color(red: 0.85, green: 1, blue: 0.84))
                    .opacity(sin(p * .pi) * (0.38 - damage * 0.25)))
        }

        for index in 0..<13 {
            let seed = random(index, salt: 1)
            let p = cycle(time / (15 + seed * 12) + seed)
            let x = 6 + random(index, salt: 2) * 166 + sin(time * 0.65 + Double(index)) * 9
            let y = 36 + p * 254
            let color = damage > 0.5 ? Color(red: 0.59, green: 0.44, blue: 0.22) : Color(red: 0.55, green: 0.73, blue: 0.25)
            let opacity = edgeFade(p) * (0.45 + seed * 0.35)
            let facing = sin(time * 1.2 + Double(index)) > 0
            pixel(&context, x: x, y: y, width: facing ? 4 : 2, height: 2, color: color.opacity(opacity))
            pixel(&context, x: x + (facing ? 1 : 0), y: y - 1, width: 2, height: 1, color: color.opacity(opacity))
            pixel(&context, x: x - 1, y: y + 2, width: 1, height: 1, color: Color.brown.opacity(opacity * 0.7))
        }

        let fireflyCount = condition == .polluted ? 0 : (condition == .tarnished ? 3 : 9)
        for index in 0..<fireflyCount {
            let phase = time * 0.8 + Double(index) * 1.9
            let x = 24 + random(index, salt: 3) * 128 + sin(phase * 0.7) * 4
            let y = 145 + random(index, salt: 4) * 120 + cos(phase * 0.5) * 5
            let alpha = 0.3 + 0.4 * (sin(phase) + 1) / 2
            sparkle(&context, x: x, y: y, color: Color(red: 1, green: 0.94, blue: 0.56), opacity: alpha, arms: false)
        }

        for (index, point) in [(10.0, 250.0), (167, 247), (23, 281), (159, 294)].enumerated() {
            plant(&context, x: point.0, y: point.1, height: 7, phase: Double(index), seaweed: false)
        }
    }

    private func ocean(_ context: inout GraphicsContext) {
        light(&context, underwater: true)
        let bubbleCount = Int(8 + vitality * 16)
        for index in 0..<bubbleCount {
            let seed = random(index, salt: 5)
            let p = cycle(time / (11 + seed * 15 + damage * 7) + seed)
            let x = 9 + random(index, salt: 6) * 162 + sin(time * 0.7 + seed * 20) * 3
            let y = 300 - p * 290
            let diameter = 2 + Double(index % 3)
            ring(&context, x: x, y: y, width: diameter, height: diameter,
                 color: Color(red: 0.82, green: 0.97, blue: 0.9).opacity(edgeFade(p) * (0.55 - damage * 0.3)))
            if index % 3 == 0 {
                pixel(&context, x: x - diameter / 2, y: y - diameter / 2, width: 1, height: 1,
                      color: Color.white.opacity(edgeFade(p) * 0.5 * vitality))
            }
        }

        // Water caustics travel across the open sand without moving the pet play area.
        for index in 0..<14 {
            let phase = time * 0.6 + Double(index) * 1.7
            let x = 28 + random(index, salt: 7) * 118 + sin(phase * 0.5) * 5
            let y = 188 + random(index, salt: 8) * 109 + cos(phase * 0.7) * 2
            let width = 5 + random(index, salt: 9) * 12
            let color = Color(red: 0.9, green: 1, blue: 0.83).opacity((0.10 + (sin(phase) + 1) * 0.06) * vitality)
            pixel(&context, x: x, y: y, width: width, height: 1, color: color)
            pixel(&context, x: x + width - 2, y: y + 1, width: 5, height: 1, color: color)
            pixel(&context, x: x + 3, y: y - 1, width: 4, height: 1, color: color)
        }

        for (index, point) in [(6.0, 303.0), (174, 305), (11, 185), (170, 184)].enumerated() {
            plant(&context, x: point.0, y: point.1, height: 12 + vitality * 12, phase: Double(index) * 2, seaweed: true)
        }
        if damage > 0.3 {
            for index in 0..<Int(8 + damage * 15) {
                let p = cycle(time / (25 + Double(index)) + random(index, salt: 10))
                let x = p * 200 - 10
                let y = 32 + random(index, salt: 11) * 245 + sin(time * 0.2 + Double(index)) * 3
                pixel(&context, x: x, y: y, width: 1 + Double(index % 2), height: 1,
                      color: Color(red: 0.66, green: 0.57, blue: 0.31).opacity(edgeFade(p) * damage * 0.5))
            }
        }
    }

    private func snow(_ context: inout GraphicsContext) {
        let snowCount = Int(18 + vitality * 30)
        for index in 0..<snowCount {
            let seed = random(index, salt: 12)
            let p = cycle(time / (10 + seed * 19) + seed)
            let x = cycle(random(index, salt: 13) + time * (0.004 + damage * 0.004)) * 190 - 5
                + sin(time * 0.75 + Double(index)) * (2 + damage * 3)
            let y = p * 330 - 5
            let opacity = edgeFade(p) * (0.5 + seed * 0.35)
            let color = damage > 0.8 ? Color(red: 0.77, green: 0.76, blue: 0.68) : Color.white
            if index % 5 == 0 {
                sparkle(&context, x: x, y: y, color: color, opacity: opacity, arms: true)
            } else {
                pixel(&context, x: x, y: y, width: 1 + Double(index % 2), height: 1 + Double(index % 2), color: color.opacity(opacity))
            }
        }

        for index in 0..<3 {
            let p = cycle(time / (12 - damage * 3) + Double(index) * 0.31)
            let x = p * 240 - 40
            let y = [79.0, 156, 250][index] + sin(time * 0.6 + Double(index)) * 2
            let alpha = sin(p * .pi) * (0.18 + damage * 0.08)
            pixel(&context, x: x, y: y, width: 22, height: 1, color: Color.white.opacity(alpha))
            pixel(&context, x: x - 8, y: y + 2, width: 19, height: 1, color: Color.white.opacity(alpha * 0.65))
            pixel(&context, x: x + 14, y: y - 1, width: 9, height: 1, color: Color.white.opacity(alpha * 0.6))
        }

        if condition != .polluted {
            for index in 0..<7 {
                let alpha = (0.22 + 0.45 * (sin(time * 0.85 + Double(index) * 1.7) + 1) / 2) * vitality
                sparkle(&context, x: 16 + random(index, salt: 14) * 146, y: 200 + random(index, salt: 15) * 101,
                        color: Color(red: 0.75, green: 0.9, blue: 1), opacity: alpha, arms: true)
            }
        }
    }

    private func light(_ context: inout GraphicsContext, underwater: Bool) {
        for index in 0..<4 {
            let sway = sin(time * 0.22 + Double(index)) * 5
            let x = 29 + Double(index) * 35 + sway
            let width = underwater ? 16.0 : 9.0
            let bottom = underwater ? 184.0 : 163.0
            var path = Path()
            path.move(to: CGPoint(x: x.rounded(), y: 0))
            path.addLine(to: CGPoint(x: (x + width).rounded(), y: 0))
            // Stepped sides keep these soft rays in the pixel-art vocabulary.
            for step in 1...8 {
                path.addLine(to: CGPoint(x: (x + width + Double(step) * 2).rounded(), y: Double(step - 1) * bottom / 8))
                path.addLine(to: CGPoint(x: (x + width + Double(step) * 2).rounded(), y: Double(step) * bottom / 8))
            }
            path.addLine(to: CGPoint(x: (x - 8).rounded(), y: bottom))
            path.closeSubpath()
            let alpha = (underwater ? 0.045 : 0.025) * (0.3 + vitality * 0.7) * (0.8 + sin(time * 0.3 + Double(index)) * 0.2)
            context.fill(path, with: .color(Color(red: 1, green: 0.97, blue: 0.76).opacity(alpha)))
        }
    }

    private func plant(_ context: inout GraphicsContext, x: Double, y: Double, height: Double, phase: Double, seaweed: Bool) {
        let color = damage > 0.5 ? Color(red: 0.43, green: 0.43, blue: 0.23) : (seaweed ? Color(red: 0.13, green: 0.55, blue: 0.38) : Color(red: 0.30, green: 0.52, blue: 0.15))
        for strand in 0..<3 {
            let length = height * (strand == 1 ? 1 : 0.72)
            for step in 0..<max(1, Int(length / 2)) {
                let fraction = Double(step) * 2 / length
                let sway = sin(time * (seaweed ? 0.8 : 1.4) + phase + Double(strand) * 0.7 - fraction) * fraction * fraction * (seaweed ? 4 : 2)
                let px = x + Double(strand - 1) * (2 + fraction * 2) + sway
                pixel(&context, x: px, y: y - Double(step) * 2, width: 2, height: 2, color: color.opacity(0.8))
                if step % 3 == 1 {
                    pixel(&context, x: px + (strand == 0 ? -2 : 1), y: y - Double(step) * 2, width: 3, height: 1,
                          color: color.opacity(0.7))
                }
            }
        }
    }

    private func haze(_ context: inout GraphicsContext) {
        for index in 0..<4 {
            let p = cycle(time / (38 + Double(index) * 8) + Double(index) * 0.24)
            let x = p * 290 - 85
            let y = 73 + Double(index) * 34 + sin(time * 0.18 + Double(index)) * 3
            let color = (habitat == .snow ? Color(red: 0.49, green: 0.47, blue: 0.41) : Color(red: 0.50, green: 0.48, blue: 0.32))
                .opacity(damage * edgeFade(p) * 0.13)
            pixel(&context, x: x, y: y, width: 67, height: 4, color: color)
            pixel(&context, x: x + 12, y: y - 3, width: 41, height: 3, color: color)
            pixel(&context, x: x - 8, y: y + 4, width: 51, height: 2, color: color)
        }
    }

    private func recovery(_ context: inout GraphicsContext, progress: Double) {
        // A gentle burst is queued while the camera is open, then plays on return.
        for index in 0..<16 {
            let angle = Double(index) * .pi * 2 / 16
            let radius = 12 + progress * 61
            let x = 90 + cos(angle) * radius
            let y = 208 + sin(angle) * radius * 0.55 - progress * 12
            sparkle(&context, x: x, y: y, color: Color(red: 1, green: 0.9, blue: 0.48),
                    opacity: sin(progress * .pi) * 0.8, arms: index % 3 == 0)
        }
    }

    private func sparkle(_ context: inout GraphicsContext, x: Double, y: Double, color: Color, opacity: Double, arms: Bool) {
        pixel(&context, x: x - 1, y: y - 1, width: 3, height: 3, color: color.opacity(opacity * 0.13))
        pixel(&context, x: x, y: y, width: 1, height: 1, color: color.opacity(opacity))
        if arms {
            pixel(&context, x: x - 1, y: y, width: 3, height: 1, color: color.opacity(opacity * 0.65))
            pixel(&context, x: x, y: y - 1, width: 1, height: 3, color: color.opacity(opacity * 0.65))
        }
    }

    private func ring(_ context: inout GraphicsContext, x: Double, y: Double, width: Double, height: Double, color: Color) {
        for index in 0..<16 {
            let angle = Double(index) * .pi / 8
            pixel(&context, x: x + cos(angle) * width / 2, y: y + sin(angle) * height / 2,
                  width: width > 8 ? 2 : 1, height: 1, color: color)
        }
    }

    private func pixel(_ context: inout GraphicsContext, x: Double, y: Double, width: Double, height: Double, color: Color) {
        context.fill(Path(CGRect(x: x.rounded(), y: y.rounded(), width: max(1, width.rounded()), height: max(1, height.rounded()))),
                     with: .color(color), style: FillStyle(antialiased: false))
    }

    private func cycle(_ value: Double) -> Double { value - floor(value) }
    private func edgeFade(_ progress: Double) -> Double { min(1, max(0, min(progress, 1 - progress) * 12)) }
    private func random(_ index: Int, salt: Int) -> Double { cycle(sin(Double(index * 127 + salt * 311)) * 43_758.5453) }
}
