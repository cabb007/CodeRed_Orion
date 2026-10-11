import Foundation

final class ReviewDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func data(forKey key: String) -> Data? { values[key] as? Data }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
}

final class GeminiMockProtocol: URLProtocol {
    static var handler: (URLRequest) throws -> (Int, Data) = { _ in (500, Data()) }
    static var requestCount = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            Self.requestCount += 1
            let (status, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main
@MainActor
struct GeminiReviewChecks {
    nonisolated static let now = Date(timeIntervalSince1970: 1_791_699_600)
    static let connection = try! GeminiDirectConnection(apiKey: "fake-personal-api-key-for-tests")
    static func assessment(_ changes: [String: Any] = [:]) -> [String: Any] {
        var value: [String: Any] = [
            "itemName": "Aluminum can", "material": "aluminum", "evidenceQuality": "high",
            "localAcceptance": "recyclable_here", "acceptanceEvidence": "material_icon", "binType": "recycling",
            "labelEvidence": "Can pictogram on the bin", "contaminated": false, "suspicious": false,
            "explanation": "Visible evidence matches the bin’s can icon.", "tip": "Empty the can first."
        ]
        value.merge(changes) { _, new in new }; return value
    }
    static func response(_ changes: [String: Any] = [:], status: String = "completed") throws -> Data {
        let encoded = try JSONSerialization.data(withJSONObject: assessment(changes))
        return try JSONSerialization.data(withJSONObject: ["status": status,
            "steps": [["type": "model_output", "content": [["type": "text", "text": String(data: encoded, encoding: .utf8)!]]]]])
    }
    static func submission(seed: UInt8 = 0, id: UUID = UUID(), at date: Date = now) -> RecyclingSubmission {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return .init(submissionId: id, photos: ["bin", "item"].enumerated().map { index, role in
            let bytes = Data([0xff, 0xd8, 0xff, seed, UInt8(index)] + Array(repeating: 0, count: 120))
            return .init(role: role, source: "camera", mimeType: "image/jpeg",
                         capturedAt: formatter.string(from: date.addingTimeInterval(Double(index - 3))), data: bytes.base64EncodedString())
        })
    }
    static func expectFailure(_ message: String, _ operation: () throws -> Void) {
        do { try operation(); preconditionFailure(message) } catch { }
    }
    static func expectAsyncFailure(_ message: String, _ operation: () async throws -> Void) async {
        do { try await operation(); preconditionFailure(message) } catch { }
    }
    static func main() async throws {
        let preferences = ReviewDefaults()
        preferences.set(GeminiDirectConnection.detailedModel, forKey: "ecogotchi.gemini.model")
        precondition(GeminiDirectConnection.preferredModel(in: preferences) == GeminiDirectConnection.defaultModel,
                     "Existing default upgrades to Quick")
        preferences.set(GeminiDirectConnection.detailedModel, forKey: "ecogotchi.gemini.model")
        precondition(GeminiDirectConnection.preferredModel(in: preferences) == GeminiDirectConnection.detailedModel,
                     "A later explicit Detailed choice survives relaunch")
        let customPreferences = ReviewDefaults()
        customPreferences.set("gemini-3.6-flash", forKey: "ecogotchi.gemini.model")
        precondition(GeminiDirectConnection.preferredModel(in: customPreferences) == "gemini-3.6-flash",
                     "Migration preserves custom models")
        precondition(GeminiDirectConnection.preferredModel(in: ReviewDefaults()) == GeminiDirectConnection.defaultModel)
        let config = try Data(contentsOf: URL(fileURLWithPath: "EcoGotchi/Resources/GeminiReview.json"))
        let capture = submission()
        let request = try GeminiReviewProtocol.request(for: capture, apiKey: connection.apiKey, model: connection.model, configuration: config)
        precondition(request.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/interactions")
        precondition(request.url?.query == nil && request.value(forHTTPHeaderField: "x-goog-api-key") == connection.apiKey)
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        precondition(body["store"] as? Bool == false)
        precondition((body["input"] as! [[String: Any]]).filter { $0["type"] as? String == "image" }.count == 2)
        precondition((body["generation_config"] as! [String: Any])["max_output_tokens"] as? Int == 2048)
        precondition((body["generation_config"] as! [String: Any])["thinking_level"] as? String == "minimal")
        let photos = (body["input"] as! [[String: Any]]).filter { $0["type"] as? String == "image" }
        precondition(photos.compactMap { $0["resolution"] as? String } == ["high", "medium"])
        precondition(photos.compactMap { $0["data"] as? String } == capture.photos.map(\.data),
                     "Both evidence images reach the reviewer in order")
        let schema = (body["response_format"] as! [String: Any])["schema"] as! [String: Any]
        precondition(Set(schema["required"] as! [String]).isDisjoint(with: ["sameItem", "sameBin", "disposalVisible"]),
                     "Two-photo assessment must not require disposal or cross-photo identity checks")
        for model in [GeminiDirectConnection.detailedModel, "gemini-2.5-flash"] {
            let detailedRequest = try GeminiReviewProtocol.request(for: capture, apiKey: connection.apiKey, model: model, configuration: config)
            let detailedBody = try JSONSerialization.jsonObject(with: detailedRequest.httpBody!) as! [String: Any]
            precondition((detailedBody["generation_config"] as! [String: Any])["thinking_level"] as? String == "low",
                         "Never send unsupported minimal thinking to 3.8 or older/custom models")
            precondition((detailedBody["input"] as! [[String: Any]]).allSatisfy { $0["resolution"] == nil })
        }
        precondition(!String(data: request.httpBody!, encoding: .utf8)!.contains(connection.apiKey))

        let approved = try GeminiReviewProtocol.decode(response(), submissionID: capture.submissionId, now: now)
        precondition(approved.isValidReward && approved.leaves == 30 && approved.cleanup == 1)
        precondition(approved.limitation.contains("did not verify disposal"))
        for photos in [Array(capture.photos.prefix(1)), Array(capture.photos.reversed()), capture.photos + [capture.photos[1]]] {
            expectFailure("Only two photos in bin/item order may be reviewed") {
                _ = try GeminiReviewProtocol.photoHashes(.init(submissionId: UUID(), photos: photos), now: now, checkFresh: true)
            }
        }
        for evidence in ["printed_label", "material_icon", "nearby_sign"] {
            let receipt = try GeminiReviewProtocol.decode(response(["acceptanceEvidence": evidence]), submissionID: UUID(), now: now)
            precondition(receipt.isValidReward)
        }
        for acceptance in ["likely_compatible", "recyclable_here"] {
            let receipt = try GeminiReviewProtocol.decode(response([
                "acceptanceEvidence": "bin_appearance", "localAcceptance": acceptance,
                "labelEvidence": "Recycling symbol and sorting opening; no readable text"
            ]), submissionID: UUID(), now: now)
            precondition(receipt.isValidReward && receipt.leaves == 30)
            precondition(receipt.localAcceptance == "likely_compatible", "Appearance never confirms local rules")
        }
        for (bin, status) in [("general_waste", RecyclingAssessment.Status.rejected), ("unknown", .needsReview)] {
            let receipt = try GeminiReviewProtocol.decode(response(["binType": bin]), submissionID: UUID(), now: now)
            precondition(receipt.status == status && !receipt.isValidReward && receipt.leaves == 0)
        }
        let conflict = try GeminiReviewProtocol.decode(response([
            "acceptanceEvidence": "bin_appearance", "localAcceptance": "not_accepted_here"
        ]), submissionID: UUID(), now: now)
        precondition(conflict.status == .rejected && conflict.leaves == 0)
        var invalidReceipt = approved
        invalidReceipt.binType = "general_waste"
        precondition(!invalidReceipt.isValidReward, "Receipts cannot override ordinary-bin rejection")
        invalidReceipt.binType = "unknown"
        precondition(!invalidReceipt.isValidReward)
        expectFailure("Missing bin classification cannot earn rewards") {
            _ = try GeminiReviewProtocol.decode(response(["binType": NSNull()]), submissionID: UUID(), now: now)
        }
        for material in RecycledMaterial.allCases {
            let receipt = try GeminiReviewProtocol.decode(response(["material": material.rawValue]), submissionID: UUID(), now: now)
            precondition(receipt.leaves == material.leaves)
            precondition(receipt.isValidReward == (material.leaves > 0))
        }
        for changes: [String: Any] in [["acceptanceEvidence": "none"], ["evidenceQuality": "medium"],
                                       ["localAcceptance": "unknown"]] {
            let receipt = try GeminiReviewProtocol.decode(response(changes), submissionID: UUID(), now: now)
            precondition(receipt.status == .needsReview && receipt.leaves == 0 && receipt.cleanup == 0)
        }
        for changes: [String: Any] in [["contaminated": true], ["suspicious": true], ["localAcceptance": "not_accepted_here"]] {
            let receipt = try GeminiReviewProtocol.decode(response(changes), submissionID: UUID(), now: now)
            precondition(receipt.status == .rejected && !receipt.isValidReward && receipt.leaves == 0)
        }
        expectFailure("Truncated output cannot earn rewards") {
            _ = try GeminiReviewProtocol.decode(response(status: "incomplete"), submissionID: UUID(), now: now)
        }
        for changes: [String: Any] in [["binType": "made-up"], ["contaminated": "true"], ["material": "made-up"], ["explanation": ""], ["itemName": String(repeating: "x", count: 121)]] {
            expectFailure("Malformed output must fail closed") { _ = try GeminiReviewProtocol.decode(response(changes), submissionID: UUID(), now: now) }
        }
        expectFailure("Model names cannot be URLs") { _ = try GeminiDirectConnection(apiKey: connection.apiKey, model: "../../other-host") }
        expectFailure("Keys cannot contain header injection") { _ = try GeminiDirectConnection(apiKey: connection.apiKey + "\nother-header") }
        expectFailure("Expired photos cannot begin a review") {
            _ = try GeminiReviewProtocol.photoHashes(submission(at: now.addingTimeInterval(-700)), now: now, checkFresh: true)
        }
        let duplicateFrames = RecyclingSubmission(submissionId: UUID(), photos: capture.photos.enumerated().map { index, photo in
            RecyclingPhoto(role: photo.role, source: photo.source, mimeType: photo.mimeType, capturedAt: photo.capturedAt, data: capture.photos[0].data)
        })
        expectFailure("Repeated photos cannot start Actual review") { _ = try GeminiReviewProtocol.photoHashes(duplicateFrames, now: now, checkFresh: true) }
        precondition(RecyclingMode.demo.automaticallyAccepts() && !RecyclingMode.ai.automaticallyAccepts())
        precondition(RecyclingMode.ai.automaticallyAccepts(samplePhotos: true), "Sample artwork always stays offline")

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [GeminiMockProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        GeminiMockProtocol.handler = { request in
            precondition(request.url?.host == "generativelanguage.googleapis.com")
            if request.httpMethod == "GET" {
                precondition(request.httpBody == nil)
                return (200, Data("{\"name\":\"models/gemini-3.8-flash\"}".utf8))
            }
            return (200, try response())
        }
        try await connection.testConnection(session: session)
        let defaults = ReviewDefaults(suiteName: "EcoGotchi.GeminiChecks")!
        let client = GeminiReviewClient(defaults: defaults, dailyLimit: 1)
        let beforeCancelled = GeminiMockProtocol.requestCount
        let cancelled = Task {
            try await client.assess(capture, connection: connection, configuration: config, session: session, now: now)
        }
        cancelled.cancel()
        await expectAsyncFailure("Cancelled review must not produce a receipt") { _ = try await cancelled.value }
        precondition(GeminiMockProtocol.requestCount == beforeCancelled && client.reviewsRemaining(at: now) == 1,
                     "Cancellation before upload cannot send photos or reserve quota")
        let receipt = try await client.assess(capture, connection: connection, configuration: config, session: session, now: now)
        precondition(receipt.isValidReward && client.reviewsRemaining(at: now) == 0)
        let count = GeminiMockProtocol.requestCount
        let reopened = GeminiReviewClient(defaults: defaults, dailyLimit: 1)
        let retry = try await reopened.assess(capture, connection: connection, configuration: config, session: session, now: now.addingTimeInterval(700))
        precondition(retry.receiptId == receipt.receiptId && GeminiMockProtocol.requestCount == count, "Saved receipts work after relaunch, expiry, and daily limit")
        await expectAsyncFailure("Same ID cannot be reused with changed photos") {
            _ = try await reopened.assess(submission(seed: 1, id: capture.submissionId), connection: connection, configuration: config, session: session, now: now)
        }
        await expectAsyncFailure("Quota is enforced before the network call") {
            _ = try await reopened.assess(submission(seed: 2), connection: connection, configuration: config, session: session, now: now)
        }
        precondition(GeminiMockProtocol.requestCount == count)
        await expectAsyncFailure("Approved photos cannot earn again with a new ID") {
            _ = try await reopened.assess(submission(at: now.addingTimeInterval(86_401)), connection: connection, configuration: config, session: session, now: now.addingTimeInterval(86_401))
        }
        _ = try await reopened.assess(submission(seed: 3, at: now.addingTimeInterval(86_401)), connection: connection, configuration: config, session: session, now: now.addingTimeInterval(86_401))
        let persisted = String(data: defaults.data(forKey: "ecogotchi.gemini.reviewHistory.v1")!, encoding: .utf8)!
        precondition(!persisted.contains(capture.photos[0].data) && !persisted.contains(connection.apiKey), "Neither photos nor API keys enter history")

        for status in [400, 401, 403, 404, 429, 503] {
            GeminiMockProtocol.handler = { _ in (status, Data()) }
            await expectAsyncFailure("Provider errors must not produce a receipt") { _ = try await GeminiDirectConnection.send(request, session: session) }
        }
        let failureDefaults = ReviewDefaults(suiteName: "EcoGotchi.GeminiFailures")!
        let failing = GeminiReviewClient(defaults: failureDefaults, dailyLimit: 1)
        await expectAsyncFailure("Failed review consumes the reserved attempt") {
            _ = try await failing.assess(capture, connection: connection, configuration: config, session: session, now: now)
        }
        precondition(failing.reviewsRemaining(at: now) == 0)
        print("Gemini checks passed: Quick/Detailed payloads, default migration, cancellation, direct HTTPS, assessment policy, retries, duplicates, persistent quota, provider failures, and local privacy.")
    }
}
