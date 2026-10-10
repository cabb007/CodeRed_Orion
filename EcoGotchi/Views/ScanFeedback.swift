import SwiftUI
import AVFoundation
import Combine

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
