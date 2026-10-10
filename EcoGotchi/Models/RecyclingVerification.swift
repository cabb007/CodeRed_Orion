import Foundation

enum RecyclingMode: String, CaseIterable, Identifiable {
    case demo, ai
    var id: String { rawValue }
    var title: String { self == .demo ? "Demo" : "AI review" }
    static let demoLeaves = 20
}

enum RecycledMaterial: String, Codable, CaseIterable {
    case aluminum, steel, plastic, glass, cardboard, paper, other, unknown

    // Game balance values, not measurements of environmental benefit.
    var leaves: Int {
        switch self {
        case .aluminum: 30
        case .steel: 25
        case .plastic, .glass: 20
        case .cardboard: 15
        case .paper: 10
        case .other, .unknown: 0
        }
    }
}

struct RecyclingPhoto: Codable {
    let role: String
    let source: String
    let mimeType: String
    let capturedAt: String
    let data: String
}

struct RecyclingSubmission: Codable {
    let submissionId: UUID
    let photos: [RecyclingPhoto]
}

struct RecyclingAssessment: Codable {
    enum Status: String, Codable { case approved, needsReview = "needs_review", rejected }
    let submissionId: UUID
    let receiptId: UUID
    let reviewedAt: String
    let status: Status
    let itemName: String
    let material: RecycledMaterial
    let leaves: Int
    let cleanup: Int
    let explanation: String
    let tip: String
    let labelEvidence: String
    let evidenceQuality: String
    let verification: String
    let limitation: String
    // Optional so receipts cached by earlier servers remain readable.
    var localAcceptance: String? = nil
    var acceptanceEvidence: String? = nil

    var needsBinGuidance: Bool {
        status == .needsReview && (localAcceptance == "unknown" || acceptanceEvidence == "none")
    }

    private var hasValidBinEvidence: Bool {
        if localAcceptance == nil && acceptanceEvidence == nil { return true }
        return localAcceptance == "recyclable_here" &&
            ["printed_label", "material_icon", "nearby_sign"].contains(acceptanceEvidence ?? "")
    }

    var isValidReward: Bool {
        status == .approved && hasValidBinEvidence && verification == "gemini_visual_review" && evidenceQuality == "high" &&
        material.leaves > 0 && leaves == material.leaves && cleanup == 1 &&
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && itemName.count <= 120
    }
}

enum VerificationError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): message }
    }
}
