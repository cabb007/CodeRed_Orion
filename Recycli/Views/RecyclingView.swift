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
    @State private var modeSessionID: UUID?
    @State private var draft = RecyclingCaptureDraft()
    @State private var showSettings = false
    @State private var inspecting: RecyclingCaptureStep?
    @State private var configured = RecyclingReviewProvider.current.isConfigured
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
    @State private var reviewTask: Task<Void, Never>?
    @State private var scanTask: Task<Void, Never>?

    private var result: RecyclingAssessment? { store.scanReview?.assessment }
    private var displayedLeaves: Int { store.scanReview?.leaves ?? earnedLeaves }
    private var displayedCleanup: Int { store.scanReview?.cleanup ?? clearedLitter }
    private var wasAlreadyRewarded: Bool { store.scanReview?.alreadyRewarded ?? alreadyRewarded }
    private var reviewIsPreview: Bool {
        if let review = store.scanReview { return review.previewID != nil }
        return store.isDeveloperMode
    }
    private var displayedTotal: Int {
        if let review = store.scanReview, review.previewID == nil { return store.savedLeafTotal }
        return store.state.points
    }
    private var hasResult: Bool { result != nil || completedPreview || completedDemo }
    private var sampleMode: Bool { store.isDeveloperMode && useSamplePhotos }
    private var autoAccept: Bool { store.recyclingMode.automaticallyAccepts(samplePhotos: sampleMode) }
    private var canCapture: Bool { autoAccept || configured }
    private var captureBusy: Bool { camera.capturing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if reviewIsPreview {
                        Text(store.scanReview == nil && (autoAccept || showRewardPreview)
                             ? "DEVELOPER PREVIEW · simulated review, no uploads"
                             : "DEVELOPER PREVIEW · Actual AI review, temporary rewards")
                            .font(.caption2.bold()).padding(10).pixelPanel(Palette.gold)
                    } else if store.scanReview == nil && store.isDemoRecycling {
                        Label("Demo · auto-accept on", systemImage: "sparkles")
                            .font(.caption.bold()).padding(10).pixelPanel(Palette.sage)
                    }
                    if let review = store.scanReview, review.status != .finished { ongoingReview(review) }
                    else if hasResult { reviewResult }
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
                if let review = store.scanReview, review.status != .finished { reviewFooter(review) }
                else if !hasResult && canCapture { challengeFooter }
            }
            .navigationTitle(hasResult ? "Your recycling reward" : (autoAccept ? "Recycling scan" : "Recycling check"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { camera.stop(); showSettings = true } label: {
                        Image(systemName: "gearshape").frame(width: 44, height: 44)
                    }.accessibilityLabel("Scan settings")
                        .disabled(store.scanReview != nil || checking || captureBusy || (!draft.frames.isEmpty && !draft.isComplete))
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
                modeSessionID = store.modeSessionID
                if store.scanReview == nil && store.isDeveloperMode && showRewardPreview {
                    earnedLeaves = store.developer.actionReward
                    completedPreview = true
                } else if launchCameraOnOpen { startCameraIfNeeded() }
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                configured = RecyclingReviewProvider.current.isConfigured
                startCameraIfNeeded()
                finishDemoIfReady()
            }) { VerificationSettingsView() }
            .sheet(item: $inspecting) { step in photoDetail(step) }
            .onChange(of: store.modeSessionID) { _, _ in
                reviewTask?.cancel(); cancelScanFeedback()
                camera.stop(); draft.restart(); dismiss()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    cancelScanFeedback()
                    camera.stop()
                    discardIncompleteCapture()
                } else if phase == .active { startCameraIfNeeded(); finishDemoIfReady() }
            }
            .onChange(of: camera.interruptionCount) { _, _ in
                cancelScanFeedback()
                discardIncompleteCapture()
            }
            .onDisappear {
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
            Text("Take two photos and send them for one AI review. Add your Gemini key to review directly over Wi-Fi or cellular, without your Mac.")
            Button("Set up AI connection") { showSettings = true }.buttonStyle(PixelButtonStyle())
            Text("Your key stays in this iPhone’s Keychain. You can also choose an existing review server in settings.")
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
                    Text("No readable label needed. We look for the bin’s design, opening, and recycling clues.")
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
                }.frame(height: 300).clipShape(PixelFrame())
                if let cameraMessage = camera.message, !sampleMode {
                    Text(cameraMessage).font(.subheadline).foregroundStyle(.red)
                }
                if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
                Label(autoAccept ? "Photos stay on your phone. No connection needed." : "Only your 2 captures are kept. Review happens at the end.", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
                Text(autoAccept ? "Finish both scans to collect your leaves automatically." : "Finish within 10 minutes. Check what this bin accepts before depositing anything; ask the site staff if unsure.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var selectedPhotos: some View {
        VStack(alignment: .leading, spacing: 16) {
            progress
            Text(autoAccept ? "Both photos captured!" : "Ready for one review").font(.title2.bold())
            Text(autoAccept ? "Your demo scan is complete. Collect your leaves and watch the habitat recover." : "Check that the bin and item are clear. A readable label is optional. Tap either photo to look closer.")
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
                Text(RecyclingReviewProvider.current.uploadNotice)
                    .font(.caption).foregroundStyle(.secondary)
                Text("Likely recycling matches earn 10–30 leaves based on material. Unclear or rejected reviews earn 0. Local collection rules can differ; disposal is not verified.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
            if checking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(autoAccept ? "Adding your leaves…" : "Starting review…").font(.subheadline)
                }
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
            if checking && !autoAccept {
                Button("Cancel review") { reviewTask?.cancel() }
                    .font(.subheadline).frame(minHeight: 44)
            } else if !draft.frames.isEmpty {
                Button("Start over") { startAgain() }.font(.subheadline).frame(minHeight: 44)
                    .disabled(checking || captureBusy)
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(Palette.cream)
    }

    private func ongoingReview(_ review: ScanReview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(review.status == .reviewing ? "You’re free to play!" : "Let’s try that again")
                .font(.title2.bold())
            Text("Scan for \(review.habitat.title)").font(.subheadline.bold())
            if review.status == .reviewing {
                TimelineView(.periodic(from: review.startedAt, by: 1)) { context in
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("\(review.title) · \(max(0, Int(context.date.timeIntervalSince(review.startedAt))))s")
                            .font(.subheadline).monospacedDigit()
                    }
                }
                Text("Return to your habitat while Gemini reviews your bin and item. Approved leaves will appear automatically, and you can tap the review banner for the result.")
                    .font(.subheadline)
                Text("Keep Recycli open while you play. Leaving the app may pause the review; closing the app completely discards unfinished scans.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(review.message ?? "The review couldn’t finish. No leaves were added.")
                    .font(.subheadline).foregroundStyle(.red)
                Text("Your two photos are still here for a retry. Take new photos if they’re more than 10 minutes old.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 18)
    }

    private func reviewFooter(_ review: ScanReview) -> some View {
        VStack(spacing: 4) {
            Button("Back to my habitat") { dismiss() }
                .buttonStyle(PixelButtonStyle()).frame(maxWidth: .infinity)
            if review.status == .reviewing {
                Button(review.cancelling ? "Cancelling…" : "Cancel review") { store.cancelScanReview() }
                    .disabled(review.cancelling).frame(minHeight: 44)
            } else {
                Button("Retry review") { store.retryScanReview() }.frame(minHeight: 44)
                Button("Take new photos") { startAgain() }.frame(minHeight: 44)
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(Palette.cream)
    }

    private var captureButtonTitle: String {
        if camera.capturing { return "Capturing…" }
        if camera.starting { return "Opening camera…" }
        if !sampleMode && !camera.ready { return camera.message == nil ? "Start camera" : "Try camera again" }
        if sampleMode { return "Capture sample \(draft.nextStep?.title.lowercased() ?? "photo")" }
        return "Capture \(draft.nextStep?.title.lowercased() ?? "photo")"
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
            PixelSprite(sprite: GameSprite(rawValue: store.state.habitat.starterID) ?? .pip, size: 100)
                .frame(maxWidth: .infinity).padding(.top, 16)
            Text(resultTitle).font(.title2.bold())
            if let result { Text("\(result.itemName) · \(result.material.rawValue.capitalized)").font(.headline) }
            Label(showRewardPreview && store.scanReview == nil ? "Preview reward · \(earnedLeaves) leaves" : (wasAlreadyRewarded ? "This action already earned leaves" : (displayedLeaves > 0 ? "+\(displayedLeaves) leaves added to your \(reviewIsPreview ? "temporary" : "total") leaf points" : "No leaves added")), systemImage: "leaf.fill")
                .font(.headline).padding(14).frame(maxWidth: .infinity, alignment: .leading).pixelPanel(Palette.sage)
            Text("Total: \(displayedTotal) leaves\(reviewIsPreview ? " (temporary)" : "")").font(.subheadline.bold())
            if let result {
                Text(result.explanation).font(.subheadline)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sorting tip", systemImage: "lightbulb").font(.subheadline.bold())
                    Text(result.tip).font(.subheadline)
                    Text("Bin evidence: \(result.labelEvidence)").font(.caption).foregroundStyle(.secondary)
                }.padding(14).pixelPanel(Palette.paper)
                if result.needsBinGuidance {
                    Text("Show the whole bin and opening in good light. A recycling symbol or sorting station can help; a plain wastebasket may be too ambiguous.")
                        .font(.subheadline)
                }
                Text(result.limitation).font(.caption).foregroundStyle(.secondary)
                if reviewIsPreview {
                    Text("Actual AI review. Rewards only affect this preview; your saved habitat is unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if completedDemo {
                Text("Both photos were automatically accepted in demo mode. Your leaves and habitat progress are saved on this phone.")
                    .font(.subheadline)
            } else {
                Text(showRewardPreview ? "This celebration is a preview. Your habitat hasn’t changed." : "Simulated approval. Only your temporary habitat changed.")
                    .font(.subheadline)
            }
            if displayedCleanup > 0 { Text("\(displayedCleanup) piece(s) of virtual litter cleared.").font(.caption) }
            if let review = store.scanReview {
                Text("Reviewed for \(review.habitat.title).").font(.caption).foregroundStyle(.secondary)
                Button("Scan another item") { startAgain() }.buttonStyle(PixelButtonStyle())
            }
            Button("Back to my habitat") { store.dismissScanReview(); dismiss() }
                .buttonStyle(PixelButtonStyle(secondary: displayedLeaves == 0))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultTitle: String {
        if completedPreview { return "A little greener!" }
        if completedDemo { return alreadyRewarded ? "Already collected!" : "Scan complete!" }
        if result?.needsBinGuidance == true { return "Bin unclear" }
        switch result?.status {
        case .approved: return wasAlreadyRewarded ? "Already added to your journal" : "Looks like a recycling match!"
        case .rejected: return "This item didn’t qualify"
        default: return "We couldn’t confirm enough"
        }
    }

    private func startCameraIfNeeded() {
        guard !sampleMode, !(store.isDeveloperMode && showRewardPreview), canCapture,
              store.scanReview == nil, !hasResult, !draft.isComplete, !showSettings, scenePhase == .active else { return }
        camera.start()
    }

    private func captureCurrentStep() {
        guard let step = draft.nextStep, !captureBusy, !checking else { return }
        error = nil
        if sampleMode {
            if let image = sampleImage(for: step) { accept(image, at: Date()) }
        } else if !camera.ready { camera.start() }
        else { camera.capture { accept($0, at: $1) } }
    }

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
        feedback.play(step, soundEnabled: store.scanSounds)
        UIAccessibility.post(notification: .announcement, argument: step.successMessage)
        if !reduceMotion { flashOpacity = 0.55 }
        scanTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(80))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { flashOpacity = 0 }
                try await Task.sleep(for: .milliseconds(570))
                try Task.checkCancellation()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { scannedStep = nil }
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
        guard modeSessionID == store.modeSessionID, let step = draft.nextStep, !hasResult else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let quickReview = !autoAccept && RecyclingReviewProvider.current == .direct
            && GeminiDirectConnection.savedModel == GeminiDirectConnection.defaultModel
        // Preserve bin text; reduce upload size for the item photo.
        let smallerUpload = quickReview && step != .bin
        let longestEdge: CGFloat = smallerUpload ? 960 : 1200
        let scale = min(1, longestEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: smallerUpload ? 0.65 : 0.7) else {
            error = "That photo couldn’t be prepared. Try again."; return
        }
        do {
            // Capture advances immediately; feedback never locks the next shutter.
            try draft.capture(jpeg: jpeg, at: date, allowRepeatedImages: autoAccept)
            if draft.isComplete { camera.stop() }
            celebrateCapture(step)
            finishDemoIfReady()
        } catch { self.error = error.localizedDescription }
    }

    private func sampleImage(for step: RecyclingCaptureStep) -> UIImage? {
        switch step {
        case .bin: GameArtwork.image(named: "GroveThriving")
        case .item: GameSprite.images[.can]
        }
    }

    @MainActor
    private func submit() async {
        error = nil
        defer { checking = false }
        guard let modeSessionID, store.isCurrentSession(modeSessionID), !Task.isCancelled, draft.isComplete else { return }
        if store.isDeveloperMode && autoAccept {
            let before = store.state.litter
            let beforeLeaves = store.state.points
            store.record(item: "Simulated recycling review", sessionID: modeSessionID)
            earnedLeaves = store.state.points - beforeLeaves
            clearedLitter = before - store.state.litter
            completedPreview = true
            draft.restart()
            return
        }
        do {
            if store.isDemoRecycling {
                let before = store.state.litter
                let applied = store.recordDemoAction(try draft.submission(), sessionID: modeSessionID)
                earnedLeaves = applied ? RecyclingMode.demoLeaves : 0
                alreadyRewarded = !applied
                clearedLitter = before - store.state.litter
                completedDemo = true
                draft.restart()
                return
            }
            let provider = RecyclingReviewProvider.current
            try store.startScanReview(draft.submission()) { try await provider.assess($0) }
            draft.restart()
        } catch is CancellationError {
            error = "Review cancelled. Your photos are ready to retry; no leaves were added."
        }
        catch { self.error = error.localizedDescription }
    }

    private func startAgain() {
        store.dismissScanReview()
        cancelScanFeedback()
        draft.restart()
        completedDemo = false
        completedPreview = false
        earnedLeaves = 0
        clearedLitter = 0
        alreadyRewarded = false
        error = nil
        startCameraIfNeeded()
    }
}
