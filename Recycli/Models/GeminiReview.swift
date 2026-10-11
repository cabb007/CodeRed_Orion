import Foundation
import CryptoKit

// Mirrors server/policy.mjs: the model assesses evidence; app code assigns rewards.
struct GeminiPhotoAssessment: Decodable {
    let itemName: String
    let material: RecycledMaterial
    let evidenceQuality: String
    let binType: String
    let localAcceptance: String
    let acceptanceEvidence: String
    let labelEvidence: String
    let contaminated: Bool
    let suspicious: Bool
    let explanation: String
    let tip: String

    func receipt(for submissionID: UUID, at now: Date) throws -> RecyclingAssessment {
        func valid(_ text: String, limit: Int) -> Bool {
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= limit
        }
        guard valid(itemName, limit: 120), valid(explanation, limit: 800), valid(tip, limit: 500),
              valid(labelEvidence, limit: 300), ["high", "medium", "low"].contains(evidenceQuality),
              ["recycling", "general_waste", "unknown"].contains(binType),
              ["recyclable_here", "likely_compatible", "not_accepted_here", "unknown"].contains(localAcceptance),
              ["printed_label", "material_icon", "nearby_sign", "bin_appearance", "none"].contains(acceptanceEvidence) else {
            throw VerificationError.message("Gemini returned an incomplete assessment. No leaves were added.")
        }
        // Appearance supports a likely match, never a claim about local collection rules.
        let acceptance: String
        if acceptanceEvidence == "none" || binType == "unknown" { acceptance = "unknown" }
        else if acceptanceEvidence == "bin_appearance" && localAcceptance == "recyclable_here" {
            acceptance = "likely_compatible"
        } else { acceptance = localAcceptance }
        let status: RecyclingAssessment.Status
        if suspicious || contaminated || binType == "general_waste" || acceptance == "not_accepted_here" { status = .rejected }
        else if evidenceQuality == "high", binType == "recycling",
                ["recyclable_here", "likely_compatible"].contains(acceptance),
                material.leaves > 0 { status = .approved }
        else { status = .needsReview }
        return .init(submissionId: submissionID, receiptId: UUID(), reviewedAt: ISO8601DateFormatter().string(from: now),
                     status: status, itemName: itemName, material: material,
                     leaves: status == .approved ? material.leaves : 0, cleanup: status == .approved ? 1 : 0,
                     explanation: status == .needsReview && acceptance == "unknown"
                         ? "We couldn’t recognize a clear recycling match. Try a wider, sharper photo of the bin and its opening."
                         : explanation,
                     tip: tip, labelEvidence: labelEvidence, evidenceQuality: evidenceQuality,
                     verification: "gemini_visual_review",
                     limitation: "Visual match only; local collection rules can differ. AI did not verify disposal or downstream recycling.",
                     localAcceptance: acceptance, acceptanceEvidence: acceptanceEvidence, binType: binType)
    }
}

enum GeminiReviewProtocol {
    static let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/")!

    static func request(for submission: RecyclingSubmission, apiKey: String, model: String,
                        configuration: Data) throws -> URLRequest {
        guard let config = try JSONSerialization.jsonObject(with: configuration) as? [String: Any],
              let prompt = config["systemInstruction"] as? String,
              let schema = config["responseSchema"] as? [String: Any] else {
            throw VerificationError.message("The review configuration is missing. Reinstall the updated app.")
        }
        let fastReview = model == GeminiDirectConnection.defaultModel
        let input: [[String: Any]] = submission.photos.enumerated().flatMap { index, photo in
            var image: [String: Any] = ["type": "image", "mime_type": "image/jpeg", "data": photo.data]
            if fastReview {
                // Keep signs/icons legible; use fewer visual tokens for the item photo.
                image["resolution"] = photo.role == "bin" ? "high" : "medium"
            }
            return [["type": "text", "text": "Photo \(index + 1): \(photo.role)"], image]
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("interactions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "store": false,
            "system_instruction": prompt + (fastReview
                ? "\nKeep the JSON concise: itemName at most 6 words, labelEvidence 16 words, explanation 24 words, tip 16 words. Preserve every evidence check and express uncertainty when details are unclear." : ""),
            // Keep room for complete JSON; a tiny output cap can truncate a review.
            "generation_config": ["max_output_tokens": 2048, "thinking_level": fastReview ? "minimal" : "low", "thinking_summaries": "none"],
            "input": input,
            "response_format": ["type": "text", "mime_type": "application/json", "schema": schema]
        ])
        return request
    }

    static func decode(_ data: Data, submissionID: UUID, now: Date) throws -> RecyclingAssessment {
        guard let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              response["status"] as? String == "completed",
              let steps = response["steps"] as? [[String: Any]] else {
            throw VerificationError.message("Gemini didn’t finish the review. No leaves were added. Retry the same photos.")
        }
        let text = steps.filter { $0["type"] as? String == "model_output" }
            .flatMap { $0["content"] as? [[String: Any]] ?? [] }
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }.joined()
        guard let assessment = try? JSONDecoder().decode(GeminiPhotoAssessment.self, from: Data(text.utf8)) else {
            throw VerificationError.message("Gemini returned an unreadable review. No leaves were added.")
        }
        return try assessment.receipt(for: submissionID, at: now)
    }

    static func photoHashes(_ submission: RecyclingSubmission, now: Date, checkFresh: Bool) throws -> [String] {
        guard submission.photos.map(\.role) == ["bin", "item"] else {
            throw VerificationError.message("Capture the bin, then the item.")
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var previous = Date.distantPast
        let hashes = try submission.photos.map { photo -> String in
            guard photo.source == "camera", photo.mimeType == "image/jpeg", photo.data.count <= 2_000_000,
                  let date = formatter.date(from: photo.capturedAt), date > previous,
                  !checkFresh || (now.timeIntervalSince(date) <= 600 && date.timeIntervalSince(now) <= 30),
                  let bytes = Data(base64Encoded: photo.data), (100...1_500_000).contains(bytes.count),
                  bytes.starts(with: [0xff, 0xd8, 0xff]) else {
                throw VerificationError.message("Photos expired or couldn’t be read. Start a new camera session.")
            }
            previous = date
            return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        }
        guard Set(hashes).count == 2 else {
            throw VerificationError.message("Use a different camera photo for each step.")
        }
        return hashes
    }

    static func requestHash(_ submission: RecyclingSubmission) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: try encoder.encode(submission)).map { String(format: "%02x", $0) }.joined()
    }
}

// Only receipts and hashes persist here. Photos stay in memory. This is a private-build
// convenience, not a tamper-proof replacement for server-enforced rewards or quotas.
@MainActor
final class GeminiReviewClient {
    static let shared = GeminiReviewClient()
    private struct CachedReview: Codable {
        let requestHash: String
        let assessment: RecyclingAssessment
    }
    private struct History: Codable {
        var attempts: [Date] = []
        var receipts: [CachedReview] = []
        var approvedPhotoHashes: Set<String> = []
    }
    private let defaults: UserDefaults
    private let key = "ecogotchi.gemini.reviewHistory.v1"
    private var history: History
    private var reviewing = false
    private let dailyLimit: Int

    init(defaults: UserDefaults = .standard, dailyLimit: Int = 30) {
        self.defaults = defaults
        self.dailyLimit = dailyLimit
        history = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(History.self, from: $0) } ?? History()
    }

    func reviewsRemaining(at now: Date = Date()) -> Int {
        max(0, dailyLimit - history.attempts.filter { now.timeIntervalSince($0) < 86_400 }.count)
    }

    func assess(_ submission: RecyclingSubmission, connection: GeminiDirectConnection,
                configuration suppliedConfiguration: Data? = nil, session: URLSession? = nil,
                now: Date = Date()) async throws -> RecyclingAssessment {
        try Task.checkCancellation()
        guard !reviewing else { throw VerificationError.message("A review is already running. Please wait.") }
        let hashes = try GeminiReviewProtocol.photoHashes(submission, now: now, checkFresh: false)
        let digest = try GeminiReviewProtocol.requestHash(submission)
        if let cached = history.receipts.first(where: { $0.assessment.submissionId == submission.submissionId }) {
            guard cached.requestHash == digest else {
                throw VerificationError.message("These photos don’t match the earlier submission. Start a new capture.")
            }
            return cached.assessment
        }
        _ = try GeminiReviewProtocol.photoHashes(submission, now: now, checkFresh: true)
        guard history.approvedPhotoHashes.isDisjoint(with: hashes) else {
            throw VerificationError.message("One of these photos already earned a reward. Take a new set.")
        }
        let configuration: Data
        if let suppliedConfiguration { configuration = suppliedConfiguration }
        else if let url = Bundle.main.url(forResource: "GeminiReview", withExtension: "json") {
            configuration = try Data(contentsOf: url)
        } else { throw VerificationError.message("Review setup is missing from this build. Update the app.") }
        let request = try GeminiReviewProtocol.request(for: submission, apiKey: connection.apiKey,
                                                      model: connection.model, configuration: configuration)
        guard reviewsRemaining(at: now) > 0 else {
            throw VerificationError.message("This phone’s 30-review daily limit is reached. Try later or use Demo mode.")
        }
        reviewing = true
        defer { reviewing = false }
        history.attempts = history.attempts.filter { now.timeIntervalSince($0) < 86_400 }
        history.attempts.append(now)
        try save() // Reserve before the request; failures may still consume API quota.
        let data = try await GeminiDirectConnection.send(request, session: session)
        let assessment = try GeminiReviewProtocol.decode(data, submissionID: submission.submissionId, now: now)
        history.receipts.append(.init(requestHash: digest, assessment: assessment))
        history.receipts = Array(history.receipts.suffix(200))
        if assessment.status == .approved { history.approvedPhotoHashes.formUnion(hashes) }
        try save()
        return assessment
    }

    private func save() throws { defaults.set(try JSONEncoder().encode(history), forKey: key) }
}
