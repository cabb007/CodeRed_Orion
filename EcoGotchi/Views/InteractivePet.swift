import SwiftUI

struct InteractivePet: View {
    let animal: HabitatAnimal
    let home: CGPoint
    let playground: CGRect
    let size: CGFloat
    let roamEnabled: Bool
    let sceneActive: Bool
    let showLabel: Bool
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var gestureActive = false
    @State private var bodyState: PetBody?
    @State private var dragOrigin: CGPoint?
    @State private var translation = CGSize.zero
    @State private var tilt = 0.0
    @State private var hop = false
    @State private var reaction: String?
    @State private var affection = 0
    @State private var reactionTask: Task<Void, Never>?
    @State private var walkTarget: CGFloat?
    @State private var nextWalkAt = Date.distantPast
    @State private var walkPhase = 0.0
    @State private var facingLeft = false
    @State private var tastedFood: GameSprite?

    private var lifted: Bool { dragOrigin != nil }
    private var bounds: CGRect { PetMotion.bounds(in: playground, size: size, groundY: home.y) }
    private var center: CGPoint {
        let origin = dragOrigin ?? bodyState?.position ?? CGPoint(x: home.x, y: bounds.maxY)
        return CGPoint(x: min(bounds.maxX, max(bounds.minX, origin.x + (lifted ? translation.width : 0))),
                       y: min(bounds.maxY, max(bounds.minY, origin.y + (lifted ? translation.height : 0))))
    }
    private var walking: Bool { !lifted && walkTarget != nil && bodyState?.isGrounded == true && roamEnabled }
    private var altitude: CGFloat { max(0, bounds.maxY - center.y) }
    private var motionSettings: PetAnimationSettings {
        .init(bounds: bounds, active: sceneActive && scenePhase == .active && !reduceMotion, roam: roamEnabled)
    }

    var body: some View {
        ZStack {
            if animal.habitat != .ocean {
                Ellipse().fill(Palette.forest.opacity(altitude > 10 ? 0.12 : 0.22))
                    .frame(width: size * max(0.3, 0.65 - altitude / 600), height: size * 0.13)
                    .offset(y: altitude + size * 0.42).allowsHitTesting(false)
            }
            PixelSprite(sprite: GameSprite(rawValue: animal.id) ?? .pip, size: size)
                .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                .rotationEffect(.degrees(reduceMotion ? 0 : tilt), anchor: .top)
                .scaleEffect(reduceMotion ? 1 : (lifted ? 1.12 : (hop ? 1.10 : 1)))
                .offset(y: reduceMotion ? 0 : (hop ? -12 : (walking ? (animal.habitat == .ocean ? sin(walkPhase * 0.4) * 5 : -abs(sin(walkPhase)) * 3) : 0)))
        }
        .frame(width: max(72, size), height: max(72, size))
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if let reaction {
                VStack(spacing: 3) {
                    Text(reaction).font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 5).pixelPanel(Palette.paper, shadow: false)
                    HStack(spacing: 4) {
                        if let tastedFood { PixelSprite(sprite: tastedFood, size: 28) }
                        PetHearts().id(affection).frame(width: 70, height: 24)
                    }
                }.fixedSize().offset(y: -48).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            if showLabel || lifted {
                Text(animal.name).font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(4).background(Palette.paper, in: PixelFrame()).offset(y: 15)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .gesture(drag.exclusively(before: TapGesture().onEnded { pet() }))
        .position(center)
        .zIndex(lifted ? 100 : 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(animal.name)
        .accessibilityValue(reaction ?? "Exploring \(animal.habitat.title)")
        .accessibilityHint(store.selectedFood.map { "Double-tap to feed \($0.name)." } ?? "Double-tap to pet. Drag to pick up and play.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pet() }
        .accessibilityAction(named: "Pet \(animal.name)") { pet(feedIfSelected: false) }
        .accessibilityAction(named: "Return to starting spot") { returnHome() }
        .task(id: motionSettings) { await runMotion() }
        .onChange(of: gestureActive) { _, active in
            if !active && lifted { release(predictedTravel: .zero) }
        }
        .onChange(of: bounds) { _, _ in settleImmediately() }
        .onDisappear { reactionTask?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("habitatWorld"))
            .updating($gestureActive) { _, active, _ in active = true }
            .onChanged { value in
                if dragOrigin == nil {
                    reactionTask?.cancel()
                    reaction = nil
                    hop = false
                    walkTarget = nil
                    dragOrigin = center
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
                }
                let movement = value.translation.width - translation.width
                translation = value.translation
                withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.45)) {
                    tilt = PetMotion.swing(horizontalMovement: movement)
                }
            }
            .onEnded { value in
                release(predictedTravel: CGSize(width: value.predictedEndTranslation.width - value.translation.width,
                                                height: value.predictedEndTranslation.height - value.translation.height))
            }
    }

    private func release(predictedTravel: CGSize) {
        guard lifted else { return }
        var falling = PetBody(position: center)
        falling.drop(from: center, predictedTravel: predictedTravel, in: bounds)
        if reduceMotion { falling.settle(in: bounds) }
        bodyState = falling
        dragOrigin = nil
        translation = .zero
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55)) { tilt = 0 }
        nextWalkAt = Date().addingTimeInterval(1.5)
        showAffection("Wheee!", shouldHop: false)
    }

    @MainActor
    private func runMotion() async {
        guard motionSettings.active else { settleImmediately(); return }
        if !roamEnabled { walkTarget = nil }
        if bodyState == nil {
            var initial = PetBody(position: home)
            initial.settle(in: bounds)
            bodyState = initial
        }
        nextWalkAt = Date().addingTimeInterval(Double.random(in: 0.6...1.8))
        var lastTime = Date()
        while !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(walkTarget != nil || bodyState?.isGrounded == false ? 33 : 100)) }
            catch { return }
            guard !Task.isCancelled else { return }
            let now = Date()
            let seconds = max(0, min(0.1, now.timeIntervalSince(lastTime)))
            lastTime = now
            guard !lifted, var moving = bodyState else { continue }
            if !moving.isGrounded {
                if moving.advance(seconds: seconds, in: bounds, gravity: animal.habitat == .ocean ? 220 : 1_450) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
                    nextWalkAt = now.addingTimeInterval(Double.random(in: 0.8...1.8))
                }
                bodyState = moving
            } else if roamEnabled && reaction == nil {
                if let target = walkTarget {
                    facingLeft = target < moving.position.x
                    let previousX = moving.position.x
                    let arrived = moving.walk(toward: target, speed: animal.id == "maple" ? 27 : 21,
                                              seconds: seconds, in: bounds)
                    walkPhase += Double(abs(moving.position.x - previousX)) * 0.32
                    bodyState = moving
                    if arrived {
                        walkTarget = nil
                        nextWalkAt = now.addingTimeInterval(Double.random(in: 1.2...3.0))
                    }
                } else if now >= nextWalkAt, bounds.width > 1 {
                    walkTarget = CGFloat.random(in: bounds.minX...bounds.maxX)
                }
            }
        }
    }

    private func pet(feedIfSelected: Bool = true) {
        guard !lifted else { return }
        walkTarget = nil
        nextWalkAt = Date().addingTimeInterval(2)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        if feedIfSelected, let food = store.selectedFood {
            guard store.feedPet(animal.id) else { return }
            showAffection("Yum! Thank you!", food: GameSprite(rawValue: food.id))
            UIAccessibility.post(notification: .announcement, argument: "\(animal.name) enjoyed \(food.name)!")
            return
        }
        showAffection(["So happy!", "More pets!", "Love you!"][affection % 3])
        UIAccessibility.post(notification: .announcement, argument: "\(animal.name) is happy!")
    }

    private func showAffection(_ message: String, shouldHop: Bool = true, food: GameSprite? = nil) {
        reactionTask?.cancel()
        affection += 1
        reaction = message
        tastedFood = food
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.45)) { hop = shouldHop }
        reactionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(220))
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.5)) { hop = false }
                try await Task.sleep(for: .milliseconds(1_300))
                reaction = nil
            } catch { }
        }
    }

    private func returnHome() {
        settleImmediately()
        var initial = PetBody(position: home)
        initial.settle(in: bounds)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { bodyState = initial }
    }

    private func settleImmediately() {
        reactionTask?.cancel()
        var resting = PetBody(position: center)
        resting.settle(in: bounds)
        bodyState = resting
        dragOrigin = nil
        translation = .zero
        tilt = 0
        hop = false
        reaction = nil
        walkTarget = nil
        nextWalkAt = Date().addingTimeInterval(1.5)
    }
}

private struct PetAnimationSettings: Equatable {
    let bounds: CGRect
    let active: Bool
    let roam: Bool
}

private struct PetHearts: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false
    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<3) { index in
                PixelHeart().fill(Palette.coral).frame(width: 13, height: 12)
                    .offset(y: reduceMotion ? 0 : (floating ? -CGFloat(12 + index * 5) : 3))
                    .opacity(reduceMotion ? 1 : (floating ? 0 : 1))
            }
        }.onAppear {
            if !reduceMotion { withAnimation(.easeOut(duration: 1.4)) { floating = true } }
        }
    }
}

private struct PixelHeart: Shape {
    func path(in rect: CGRect) -> Path {
        let rows = ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
        var path = Path()
        for (y, row) in rows.enumerated() {
            for (x, cell) in row.enumerated() where cell == "1" {
                path.addRect(CGRect(x: rect.minX + CGFloat(x) * rect.width / 7,
                                    y: rect.minY + CGFloat(y) * rect.height / 6,
                                    width: rect.width / 7, height: rect.height / 6))
            }
        }
        return path
    }
}
