import SwiftUI
import AVFoundation
import Combine

struct ScanInProgressOverlay: View {
    let step: RecyclingCaptureStep
    let progress: Double
    let simulated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        guard simulated else { return "Preparing photo…" }
        switch step {
        case .bin: return "Scanning bin…"
        case .item: return "Scanning item…"
        case .disposal: return "Scanning disposal…"
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.30)
                ScanBrackets().stroke(Palette.sage, style: StrokeStyle(lineWidth: 3, lineCap: .square))
                    .padding(22)
                if !reduceMotion {
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, Palette.sage.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .frame(width: max(0, geo.size.width - 48), height: 42)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Palette.sage).frame(height: 3)
                                .shadow(color: Palette.sage, radius: 8)
                        }
                        .position(x: geo.size.width / 2, y: 32 + max(0, geo.size.height - 106) * progress)
                }
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "viewfinder")
                        Text(simulated ? "DEMO SCAN" : "PHOTO CAPTURE").tracking(1)
                        Spacer()
                    }.font(.system(size: 10, weight: .bold, design: .monospaced))
                    Spacer()
                    HStack {
                        Text(title).font(.system(.subheadline, design: .monospaced, weight: .bold))
                        Spacer()
                        Text("\(Int(progress * 100))%").font(.caption.monospacedDigit().bold())
                    }
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.white.opacity(0.2))
                            Rectangle().fill(Palette.sage).frame(width: bar.size.width * progress)
                        }
                    }.frame(height: 5)
                }.padding(34).foregroundStyle(.white)
            }
        }.allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(simulated ? "Demo scan in progress" : "Preparing captured photo")
    }
}

private struct ScanBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 22
        var path = Path()
        for (x, y, directionX, directionY) in [
            (rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0),
            (rect.minX, rect.maxY, 1.0, -1.0), (rect.maxX, rect.maxY, -1.0, -1.0)
        ] {
            path.move(to: CGPoint(x: x + directionX * length, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + directionY * length))
        }
        return path
    }
}

@MainActor
final class ScanFeedback: ObservableObject {
    private var players: [RecyclingCaptureStep: AVAudioPlayer] = [:]
    private let haptic = UINotificationFeedbackGenerator()

    init() {
        for step in RecyclingCaptureStep.allCases {
            guard let url = Bundle.main.url(forResource: "scan-\(step.rawValue)", withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = 0.65
            player.prepareToPlay()
            players[step] = player
        }
    }

    func play(_ step: RecyclingCaptureStep, soundEnabled: Bool) {
        haptic.notificationOccurred(.success)
        guard soundEnabled else { return }
        do {
            // Respect Silent Mode and mix with any music already playing.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            players.values.forEach { $0.stop() }
            players[step]?.currentTime = 0
            players[step]?.play()
        } catch { /* Capture success does not depend on audio availability. */ }
    }

    func stop() {
        players.values.forEach { $0.stop() }
    }
}

struct ScanSuccessBanner: View {
    let step: RecyclingCaptureStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if !reduceMotion {
                    ForEach(0..<8) { index in
                        Rectangle().fill(index.isMultiple(of: 2) ? Palette.gold : Palette.sage)
                            .frame(width: 5, height: 5)
                            .offset(x: cos(Double(index) * .pi / 4) * (burst ? 40 : 12),
                                    y: sin(Double(index) * .pi / 4) * (burst ? 40 : 12))
                            .opacity(burst ? 0 : 1)
                    }
                }
                Image(systemName: "checkmark").font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(Palette.forest).frame(width: 44, height: 44)
                    .background(Palette.gold, in: PixelFrame())
            }
            Text(step.successMessage).font(.system(.subheadline, design: .monospaced, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(16).foregroundStyle(Palette.paper).pixelPanel(Palette.forest)
            .accessibilityElement(children: .ignore).accessibilityLabel(step.successMessage)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.7)) { burst = true }
            }
    }
}
