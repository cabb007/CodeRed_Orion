import Foundation

@main
struct RecyclingCaptureChecks {
    static func main() throws {
        var draft = RecyclingCaptureDraft()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        precondition(draft.nextStep == .bin && !draft.isComplete)
        precondition((try? draft.submission()) == nil, "An incomplete session cannot submit")
        try draft.capture(jpeg: Data([1]), at: start)
        precondition(draft.nextStep == .item)
        precondition((try? draft.submission()) == nil)
        do { try draft.capture(jpeg: Data([1]), at: start.addingTimeInterval(1)); preconditionFailure("Duplicate photo accepted") }
        catch { precondition(draft.frames.count == 1) }
        do { try draft.capture(jpeg: Data([2]), at: start); preconditionFailure("Out-of-order timestamp accepted") }
        catch { precondition(draft.frames.count == 1) }
        try draft.capture(jpeg: Data([2]), at: start.addingTimeInterval(1))
        precondition(draft.nextStep == .disposal && !draft.isComplete)
        try draft.capture(jpeg: Data([3]), at: start.addingTimeInterval(2))
        precondition(draft.isComplete && draft.nextStep == nil)
        let submission = try draft.submission()
        precondition(submission.photos.map(\.role) == ["bin", "item", "disposal"])
        precondition(submission.photos.allSatisfy { $0.source == "camera" && $0.mimeType == "image/jpeg" })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let first = try encoder.encode(submission)
        let retry = try encoder.encode(draft.submission())
        precondition(first == retry, "Retry must preserve the same ID, photos, and capture times")
        do { try draft.capture(jpeg: Data([4]), at: start.addingTimeInterval(3)); preconditionFailure("Fourth photo accepted") }
        catch { precondition(draft.frames.count == 3) }
        let oldID = draft.id
        draft.restart()
        precondition(draft.id != oldID && draft.frames.isEmpty && draft.nextStep == .bin)
        precondition((try? draft.submission()) == nil, "Restart discards every previous photo")
        do { try draft.capture(jpeg: Data(count: 1_500_001), at: start); preconditionFailure("Oversized photo accepted") }
        catch { precondition(draft.frames.isEmpty) }
        for index in 0..<3 {
            try draft.capture(jpeg: Data([7]), at: start.addingTimeInterval(Double(index)), allowRepeatedImages: true)
        }
        precondition(draft.isComplete, "Demo accepts every captured image, including visually identical photos")
        print("Capture checks passed: ordered steps, incomplete/duplicate guards, stable retries, restart, and size limits.")
    }
}
