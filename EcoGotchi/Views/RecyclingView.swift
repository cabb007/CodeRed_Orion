import SwiftUI

struct RecyclingView: View {
    var launchCameraOnOpen = false
    var useSamplePhotos = false
    var showRewardPreview = false
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var camera = RecyclingCamera()
    @StateObject private var feedback = ScanFeedback()
    @AppStorage("ecogotchi.scanSounds") private var scanSounds = true
    @State private var draft = RecyclingCaptureDraft()
    @State private var showSettings = false
    @State private var inspecting: RecyclingCaptureStep?
    @State private var configured = VerificationConnection.isConfigured
    @State private var result: RecyclingAssessment?
    @State private var completedPreview = false
    @State private var completedDemo = false
    @State private var scannedStep: RecyclingCaptureStep?
    @State private var flashOpacity = 0.0
    @State private var error: String?
    @State private var checking = false
    @State private var prepared = false
    @State private var earnedLeaves = 0
    @State private var clearedLitter = 0
    @State private var alreadyRewarded = false
    @State private var useTimer = true
    @State private var countdown = 0
    @State private var reviewTask: Task<Void, Never>?
    @State private var timerTask: Task<Void, Never>?
    @State private var scanTask: Task<Void, Never>?

    private var hasResult: Bool { result != nil || completedPreview || completedDemo }
    private var sampleMode: Bool { store.isDeveloperMode && useSamplePhotos }
    private var autoAccept: Bool { store.isDemoRecycling || store.isDeveloperMode }
    private var canCapture: Bool { autoAccept || configured }
    private var captureBusy: Bool { camera.capturing || countdown > 0 || scannedStep != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.isDeveloperMode {
                        Text("DEVELOPER PREVIEW · simulated review, no uploads")
                            .font(.caption2.bold()).padding(10).pixelPanel(Palette.gold)
                    } else if store.isDemoRecycling {
                        Label("Demo · auto-accept on", systemImage: "sparkles")
                            .font(.caption.bold()).padding(10).pixelPanel(Palette.sage)
                    }
                    if hasResult { reviewResult }
                    else if !canCapture { connectionPrompt }
                    else if draft.isComplete { selectedPhotos }
                    else { captureStep }
                }.padding(20)
            }
            .background(Palette.cream).foregroundStyle(Palette.forest)
            .overlay { Color.white.opacity(flashOpacity).allowsHitTesting(false).accessibilityHidden(true) }
            .overlay(alignment: .top) {
                if let scannedStep {
                    ScanSuccessBanner(step: scannedStep).id(scannedStep)
                        .padding(.horizontal, 20).padding(.top, 8)
                        .transition(.opacity).allowsHitTesting(false)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !hasResult && canCapture { challengeFooter }
            }
            .navigationTitle(hasResult ? "Your recycling reward" : (autoAccept ? "Recycling scan" : "Recycling check"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { camera.stop(); showSettings = true } label: {
                        Image(systemName: "gearshape").frame(width: 44, height: 44)
                    }.accessibilityLabel("Scan settings")
                        .disabled(checking || captureBusy || (!draft.frames.isEmpty && !draft.isComplete))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.bold()).frame(width: 44, height: 44)
                    }.accessibilityLabel("Close recycling check").disabled(checking)
                }
            }
            .interactiveDismissDisabled(checking)
            .task {
                guard !prepared else { return }
                prepared = true
                if store.isDeveloperMode && showRewardPreview {
                    earnedLeaves = store.developer.actionReward
                    completedPreview = true
                } else if launchCameraOnOpen { startCameraIfNeeded() }
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                configured = VerificationConnection.isConfigured
                startCameraIfNeeded()
                finishDemoIfReady()
            }) { VerificationSettingsView() }
            .sheet(item: $inspecting) { step in photoDetail(step) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    cancelTimer()
                    cancelScanFeedback()
                    camera.stop()
                    discardIncompleteCapture()
                } else if phase == .active { startCameraIfNeeded(); finishDemoIfReady() }
            }
            .onChange(of: camera.interruptionCount) { _, _ in
                cancelTimer()
                cancelScanFeedback()
                discardIncompleteCapture()
            }
            .onDisappear {
                cancelTimer()
                cancelScanFeedback()
                camera.stop()
                reviewTask?.cancel()
            }
        }
    }

    private var connectionPrompt: some View {
        VStack(alignment: .leading, spacing: 18) {
            PixelSprite(sprite: .leaf, size: 70)
            Text("Let’s connect Gemini").font(.title2.bold())
            Text("One camera session. Three photos. One AI review. Connect your EcoGotchi server to start earning leaves from reviewed actions.")
            Button("Set up AI connection") { showSettings = true }.buttonStyle(PixelButtonStyle())
            Text("Your Gemini key stays on the server. Setup instructions are in the project’s server folder.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 24)
    }

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(Array(RecyclingCaptureStep.allCases.enumerated()), id: \.element) { index, step in
                HStack(spacing: 4) {
                    Image(systemName: draft.frames.count > index ? "checkmark.circle.fill" : "\(index + 1).circle")
                    Text(step.title).lineLimit(1).minimumScaleFactor(0.8)
                }.font(.caption.bold()).frame(maxWidth: .infinity)
                    .foregroundStyle(draft.nextStep == step ? Palette.forest : Palette.forest.opacity(0.65))
                    .accessibilityLabel("\(step.title), \(draft.frames.count > index ? "captured" : "step \(index + 1)")")
            }
        }
    }

    private var captureStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            progress
            if let step = draft.nextStep {
                Text(step.title).font(.title2.bold())
                Text(autoAccept ? step.demoInstruction : step.instruction).font(.subheadline).foregroundStyle(.secondary)
                if step == .bin && !autoAccept {
                    Text("No markings? You can still capture it. If we can’t tell what it accepts, the review will explain why it couldn’t award leaves.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ZStack {
                    if sampleMode {
                        Palette.sage
                        if let image = sampleImage(for: step) {
                            Image(uiImage: image).resizable().scaledToFit().padding(20)
                        }
                        Text("SAMPLE ARTWORK").font(.caption.bold()).padding(8)
                            .background(Palette.paper).frame(maxHeight: .infinity, alignment: .bottom)
                    } else {
                        RecyclingCameraPreview(session: camera.session)
                        if !camera.ready {
                            VStack(spacing: 12) {
                                Image(systemName: "camera").font(.largeTitle)
                                Text(camera.starting ? "Opening camera…" : "Camera preview").font(.subheadline)
                            }.foregroundStyle(.white)
                        }
                    }
                    if countdown > 0 {
                        Text("\(countdown)").font(.system(size: 72, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white).padding(24).background(.black.opacity(0.55), in: Circle())
                            .accessibilityLabel("Capturing in \(countdown) seconds")
                    }
                }.frame(height: 300).clipShape(PixelFrame())
                if step == .disposal && !sampleMode {
                    Toggle("3-second shutter timer", isOn: $useTimer)
                        .font(.subheadline).disabled(captureBusy)
                }
                if let cameraMessage = camera.message, !sampleMode {
                    Text(cameraMessage).font(.subheadline).foregroundStyle(.red)
                }
                if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
                Label(autoAccept ? "Photos stay on your phone. No connection needed." : "Only your 3 captures are kept. Review happens at the end.", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
                Text(autoAccept ? "Finish all 3 scans to collect your leaves automatically." : "Finish within 10 minutes. Check what this bin accepts before depositing anything; ask the site staff if unsure.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var selectedPhotos: some View {
        VStack(alignment: .leading, spacing: 16) {
            progress
            Text(autoAccept ? "All 3 photos captured!" : "Ready for one review").font(.title2.bold())
            Text(autoAccept ? "Your demo scan is complete. Collect your leaves and watch the grove recover." : "Check that the bin is clear and the last photo shows the item entering it. Any sorting icons or nearby signs should be visible. Tap a photo to look closer.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                ForEach(draft.frames, id: \.step) { frame in
                    Button { inspecting = frame.step } label: {
                        VStack(spacing: 8) {
                            if let image = UIImage(data: frame.jpeg) {
                                Image(uiImage: image).resizable().scaledToFit().frame(height: 120)
                                    .frame(maxWidth: .infinity).background(Palette.sage, in: PixelFrame())
                            }
                            Text(frame.step.title).font(.caption.bold())
                        }
                    }.buttonStyle(.plain).accessibilityLabel("Inspect \(frame.step.title) photo")
                        .disabled(checking || captureBusy)
                }
            }
            if !autoAccept {
                Text("Send for review uploads these 3 photos together to your EcoGotchi server and Google Gemini. The live camera preview stays on your phone. Avoid faces and personal details.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Accepted actions earn 10–30 leaves based on material. Unclear or rejected reviews earn 0. AI assesses visible evidence; it can’t prove recycling happened.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
            if checking {
                HStack(spacing: 10) { ProgressView(); Text(autoAccept ? "Adding your leaves…" : "Reviewing all 3 photos…").font(.subheadline) }
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private var challengeFooter: some View {
        VStack(spacing: 4) {
            if draft.isComplete {
                Button {
                    guard !checking, !captureBusy else { return }
                    checking = true
                    reviewTask = Task { await submit() }
                } label: {
                    Text(checking ? (autoAccept ? "Adding leaves…" : "Reviewing…") : (autoAccept ? "Collect leaves" : "Send for review"))
                        .frame(maxWidth: .infinity)
                }.buttonStyle(PixelButtonStyle()).disabled(checking || captureBusy)
            } else {
                Button { captureCurrentStep() } label: {
                    Label(captureButtonTitle, systemImage: "camera.fill").frame(maxWidth: .infinity)
                }.buttonStyle(PixelButtonStyle())
                    .disabled(captureBusy || camera.starting)
            }
            if !draft.frames.isEmpty {
                Button("Start over") { startAgain() }.font(.subheadline).frame(minHeight: 44)
                    .disabled(checking || captureBusy)
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(Palette.cream)
    }

    private var captureButtonTitle: String {
        if countdown > 0 { return "Capturing in \(countdown)…" }
        if scannedStep != nil { return "Scan complete!" }
        if camera.capturing { return "Capturing…" }
        if camera.starting { return "Opening camera…" }
        if !sampleMode && !camera.ready { return camera.message == nil ? "Start camera" : "Try camera again" }
        if sampleMode { return "Capture sample \(draft.nextStep?.title.lowercased() ?? "photo")" }
        return draft.nextStep == .disposal && useTimer ? "Capture disposal in 3 seconds" : "Capture \(draft.nextStep?.title.lowercased() ?? "photo")"
    }

    private func photoDetail(_ step: RecyclingCaptureStep) -> some View {
        NavigationStack {
            if let frame = draft.frames.first(where: { $0.step == step }), let image = UIImage(data: frame.jpeg) {
                Image(uiImage: image).resizable().scaledToFit().padding().background(Palette.cream)
                    .navigationTitle(step.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { inspecting = nil } } }
            }
        }
    }

    private var reviewResult: some View {
        VStack(alignment: .leading, spacing: 18) {
            PixelSprite(sprite: earnedLeaves > 0 ? .fern : .pip, size: 100)
                .frame(maxWidth: .infinity).padding(.top, 16)
            Text(resultTitle).font(.title2.bold())
            if let result { Text("\(result.itemName) · \(result.material.rawValue.capitalized)").font(.headline) }
            Label(alreadyRewarded ? "This action already earned leaves" : "\(earnedLeaves) leaves\(completedPreview ? " (preview)" : " earned")", systemImage: "leaf.fill")
                .font(.headline).padding(14).frame(maxWidth: .infinity, alignment: .leading).pixelPanel(Palette.sage)
            if let result {
                Text(result.explanation).font(.subheadline)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sorting tip", systemImage: "lightbulb").font(.subheadline.bold())
                    Text(result.tip).font(.subheadline)
                    Text("Bin evidence: \(result.labelEvidence)").font(.caption).foregroundStyle(.secondary)
                }.padding(14).pixelPanel(Palette.paper)
                if result.needsBinGuidance {
                    Text("A missing label doesn’t mean you recycled incorrectly. We need a visible clue about what this bin accepts, such as a material icon or a nearby sorting sign. Ask the site staff if none are available.")
                        .font(.subheadline)
                }
                Text(result.limitation).font(.caption).foregroundStyle(.secondary)
            } else if completedDemo {
                Text("All three photos were automatically accepted in demo mode. Your leaves and habitat progress are saved on this phone.")
                    .font(.subheadline)
            } else {
                Text(showRewardPreview ? "This celebration is a preview. Your habitat hasn’t changed." : "Simulated approval. Only your temporary habitat changed.")
                    .font(.subheadline)
            }
            if clearedLitter > 0 { Text("\(clearedLitter) piece(s) of virtual litter cleared.").font(.caption) }
            if result?.status != .approved && !completedPreview && !completedDemo {
                Button("Start a new capture") { startAgain() }.buttonStyle(PixelButtonStyle())
            }
            Button("Back to my habitat") { dismiss() }.buttonStyle(PixelButtonStyle(secondary: earnedLeaves == 0))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultTitle: String {
        if completedPreview { return "A little greener!" }
        if completedDemo { return alreadyRewarded ? "Already collected!" : "Scan complete!" }
        if result?.needsBinGuidance == true { return "Bin rules unclear" }
        switch result?.status {
        case .approved: return alreadyRewarded ? "Already added to your journal" : "AI review passed!"
        case .rejected: return "This action didn’t qualify"
        default: return "We couldn’t confirm enough"
        }
    }

    private func startCameraIfNeeded() {
        guard !sampleMode, !(store.isDeveloperMode && showRewardPreview), canCapture,
              !hasResult, !draft.isComplete, !showSettings, scenePhase == .active else { return }
        camera.start()
    }

    private func captureCurrentStep() {
        guard let step = draft.nextStep, !captureBusy, !checking else { return }
        error = nil
        if sampleMode {
            if let image = sampleImage(for: step) { accept(image, at: Date()) }
        } else if !camera.ready { camera.start() }
        else if step == .disposal && useTimer {
            countdown = 3
            timerTask = Task { @MainActor in
                do {
                    for value in stride(from: 3, through: 1, by: -1) {
                        countdown = value
                        try await Task.sleep(for: .seconds(1))
                    }
                    try Task.checkCancellation()
                    countdown = 0
                    camera.capture { accept($0, at: $1) }
                } catch { countdown = 0 }
            }
        } else { camera.capture { accept($0, at: $1) } }
    }

    private func cancelTimer() { timerTask?.cancel(); timerTask = nil; countdown = 0 }

    private func cancelScanFeedback() {
        scanTask?.cancel()
        scanTask = nil
        scannedStep = nil
        flashOpacity = 0
        feedback.stop()
    }

    private func celebrateCapture(_ step: RecyclingCaptureStep) {
        scanTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { scannedStep = step }
        feedback.play(step, soundEnabled: scanSounds)
        UIAccessibility.post(notification: .announcement, argument: step.successMessage)
        if !reduceMotion { flashOpacity = 0.55 }
        scanTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(80))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { flashOpacity = 0 }
                try await Task.sleep(for: .milliseconds(1_220))
                try Task.checkCancellation()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { scannedStep = nil }
                finishDemoIfReady()
            } catch { }
        }
    }

    private func finishDemoIfReady() {
        guard autoAccept, draft.isComplete, !hasResult, !checking,
              !captureBusy, !showSettings, scenePhase == .active else { return }
        checking = true
        reviewTask = Task { await submit() }
    }

    private func discardIncompleteCapture() {
        guard !hasResult, !draft.isComplete, !draft.frames.isEmpty else { return }
        draft.restart()
        error = "The camera session ended. Start with the bin again."
    }

    private func accept(_ image: UIImage, at date: Date) {
        guard let step = draft.nextStep, !hasResult else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scale = min(1, 1200 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.7) else {
            error = "That photo couldn’t be prepared. Try again."; return
        }
        do {
            try draft.capture(jpeg: jpeg, at: date, allowRepeatedImages: autoAccept)
            if draft.isComplete { camera.stop() }
            celebrateCapture(step)
        } catch { self.error = error.localizedDescription }
    }

    private func sampleImage(for step: RecyclingCaptureStep) -> UIImage? {
        switch step {
        case .bin: UIImage(named: "GroveThriving")
        case .item: GameSprite.images[.can]
        case .disposal: UIImage(named: "GroveTarnished")
        }
    }

    @MainActor
    private func submit() async {
        error = nil
        defer { checking = false }
        guard !Task.isCancelled, draft.isComplete else { return }
        if store.isDeveloperMode {
            let before = store.state.litter
            earnedLeaves = store.developer.actionReward
            store.record(item: "Simulated recycling review")
            clearedLitter = before - store.state.litter
            completedPreview = true
            draft.restart()
            return
        }
        do {
            if store.isDemoRecycling {
                let before = store.state.litter
                let applied = store.recordDemoAction(try draft.submission())
                earnedLeaves = applied ? RecyclingMode.demoLeaves : 0
                alreadyRewarded = !applied
                clearedLitter = before - store.state.litter
                completedDemo = true
                draft.restart()
                return
            }
            let review = try await VerificationConnection.current().assess(draft.submission())
            try Task.checkCancellation()
            let before = store.state.litter
            if review.status == .approved {
                let applied = store.recordReviewedAction(review)
                earnedLeaves = applied ? review.leaves : 0
                alreadyRewarded = !applied
                clearedLitter = before - store.state.litter
            }
            result = review
            draft.restart()
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }

    private func startAgain() {
        cancelTimer()
        cancelScanFeedback()
        draft.restart()
        result = nil
        completedDemo = false
        completedPreview = false
        earnedLeaves = 0
        clearedLitter = 0
        alreadyRewarded = false
        error = nil
        startCameraIfNeeded()
    }
}
