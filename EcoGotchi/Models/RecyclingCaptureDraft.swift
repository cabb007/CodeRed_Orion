import Foundation

enum RecyclingCaptureStep: String, CaseIterable, Identifiable {
    case bin, item, disposal
    var id: String { rawValue }
    var title: String {
        switch self { case .bin: "Your bin"; case .item: "Your item"; case .disposal: "Disposal" }
    }
    var instruction: String {
        switch self {
        case .bin: "Show the whole bin and its opening. Include any sorting icons, labels, or nearby signs if available. A written label is optional."
        case .item: "Show one item clearly, including its material markings. Keep the same bin nearby."
        case .disposal: "Show that item entering the same bin. Use the timer or ask someone to help. Never reach inside."
        }
    }
    var successMessage: String {
        switch self {
        case .bin: "Successfully scanned bin"
        case .item: "Successfully scanned item"
        case .disposal: "Successfully scanned disposal"
        }
    }
    var demoInstruction: String {
        switch self {
        case .bin: "Point your camera at the bin and take a picture."
        case .item: "Take a picture of your item."
        case .disposal: "Take the final picture to finish your scan. Use the timer if you need both hands."
        }
    }
}

// Memory only. One ID survives network retries; restarting always creates a new sequence.
struct RecyclingCaptureDraft {
    struct Frame {
        let step: RecyclingCaptureStep
        let jpeg: Data
        let capturedAt: Date
    }
    private(set) var id = UUID()
    private(set) var frames: [Frame] = []
    var isComplete: Bool { frames.count == RecyclingCaptureStep.allCases.count }
    var nextStep: RecyclingCaptureStep? {
        isComplete ? nil : RecyclingCaptureStep.allCases[frames.count]
    }

    mutating func capture(jpeg: Data, at date: Date = Date(), allowRepeatedImages: Bool = false) throws {
        guard let step = nextStep, !jpeg.isEmpty, jpeg.count <= 1_500_000 else {
            throw VerificationError.message("This photo couldn’t be added. Please restart the capture.")
        }
        guard date.timeIntervalSince1970.isFinite,
              frames.last.map({ date > $0.capturedAt }) ?? true,
              allowRepeatedImages || !frames.contains(where: { $0.jpeg == jpeg }) else {
            throw VerificationError.message("Take a new photo for this step.")
        }
        frames.append(Frame(step: step, jpeg: jpeg, capturedAt: date))
    }

    mutating func restart() { self = RecyclingCaptureDraft() }

    func submission() throws -> RecyclingSubmission {
        guard isComplete else { throw VerificationError.message("Capture the bin, item, and disposal first.") }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return RecyclingSubmission(submissionId: id, photos: frames.map {
            RecyclingPhoto(role: $0.step.rawValue, source: "camera", mimeType: "image/jpeg",
                           capturedAt: formatter.string(from: $0.capturedAt), data: $0.jpeg.base64EncodedString())
        })
    }
}
