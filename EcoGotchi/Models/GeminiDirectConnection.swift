import Foundation
import Security

enum RecyclingReviewProvider: String, CaseIterable, Identifiable {
    case direct, server
    static let preferenceKey = "ecogotchi.reviewProvider"
    var id: String { rawValue }
    var title: String { self == .direct ? "On iPhone" : "Review server" }
    static var current: Self {
        Self(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .direct
    }
    var isConfigured: Bool {
        self == .direct ? GeminiDirectConnection.isConfigured : VerificationConnection.isConfigured
    }
    var uploadNotice: String {
        self == .direct
            ? "Send for review sends these 2 photos directly to Google Gemini. Your live camera preview stays on your phone. Avoid faces and personal details."
            : "Send for review sends these 2 photos to your review server and Google Gemini. Your live camera preview stays on your phone. Avoid faces and personal details."
    }
    @MainActor
    func assess(_ submission: RecyclingSubmission) async throws -> RecyclingAssessment {
        switch self {
        case .direct: return try await GeminiReviewClient.shared.assess(submission, connection: .current())
        case .server: return try await VerificationConnection.current().assess(submission)
        }
    }
}

struct GeminiDirectConnection {
    let apiKey: String
    let model: String
    static let defaultModel = "gemini-3.5-flash-lite"
    static let detailedModel = "gemini-3.8-flash"
    static var savedModel: String { preferredModel() }

    // Upgrade the previous default once. Preserve custom models and any later
    // explicit choice of Detailed, including after the app is relaunched.
    static func preferredModel(in defaults: UserDefaults = .standard) -> String {
        let saved = defaults.string(forKey: "ecogotchi.gemini.model")
        if !defaults.bool(forKey: "ecogotchi.gemini.fastDefault.v1") {
            defaults.set(true, forKey: "ecogotchi.gemini.fastDefault.v1")
            if saved == nil || saved == detailedModel {
                defaults.set(defaultModel, forKey: "ecogotchi.gemini.model")
                return defaultModel
            }
        }
        return saved ?? defaultModel
    }
    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "org.ecogotchi.gemini", kSecAttrAccount as String: "personal-api-key"]
    }
    static var savedKey: String {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static var isConfigured: Bool { (try? current()) != nil }
    static func current() throws -> Self { try .init(apiKey: savedKey, model: savedModel) }

    init(apiKey: String, model: String = defaultModel) throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (20...256).contains(key.count), key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              key.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }) else {
            throw VerificationError.message("Paste your Gemini API key from Google AI Studio. Use the key value only.")
        }
        guard model.range(of: "^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$", options: .regularExpression) != nil else {
            throw VerificationError.message("Enter a Gemini model name, such as \(Self.defaultModel).")
        }
        self.apiKey = key
        self.model = model
    }

    func save() throws {
        var query = Self.keychainQuery
        let value = Data(apiKey.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = value
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw VerificationError.message("The Gemini key couldn’t be saved to Keychain. Try again.")
        }
        UserDefaults.standard.set(model, forKey: "ecogotchi.gemini.model")
        UserDefaults.standard.set(true, forKey: "ecogotchi.gemini.fastDefault.v1")
    }

    static func removeKey() throws {
        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VerificationError.message("The saved key couldn’t be removed. Try again.")
        }
    }

    // Metadata check only: no images and no model generation.
    func testConnection(session: URLSession? = nil) async throws {
        var request = URLRequest(url: GeminiReviewProtocol.baseURL.appendingPathComponent("models/\(model)"))
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let data = try await Self.send(request, session: session)
        struct ModelInfo: Decodable { let name: String }
        guard let info = try? JSONDecoder().decode(ModelInfo.self, from: data), info.name.hasPrefix("models/") else {
            throw VerificationError.message("Google didn’t return model information. Check the key and model.")
        }
    }

    // Reuse the HTTPS connection across setup and scans, without a disk cache or cookies.
    private static let reviewSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration, delegate: NoGeminiRedirects(), delegateQueue: nil)
    }()

    static func send(_ request: URLRequest, session suppliedSession: URLSession? = nil) async throws -> Data {
        let session = suppliedSession ?? reviewSession
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            switch (error as? URLError)?.code {
            case .notConnectedToInternet, .dataNotAllowed:
                throw VerificationError.message("Connect your iPhone to Wi-Fi or enable cellular data for EcoGotchi. No Mac connection is needed.")
            case .timedOut:
                throw VerificationError.message("Gemini took too long to respond. Retry the same photos. No leaves were added.")
            default:
                throw VerificationError.message("Couldn’t reach Google Gemini. Check your iPhone’s internet connection and retry.")
            }
        }
        guard let http = response as? HTTPURLResponse else {
            throw VerificationError.message("Google returned an invalid response. Please retry.")
        }
        switch http.statusCode {
        case 200: return data
        case 401, 403:
            throw VerificationError.message("Google didn’t accept this key or its permissions. Check your Gemini key in Scan settings.")
        case 404:
            throw VerificationError.message("This Gemini model isn’t available. Check the model in Scan settings.")
        case 429:
            throw VerificationError.message("Gemini is busy or your API quota is used up. Try later. No leaves were added.")
        case 400:
            throw VerificationError.message("Gemini rejected the request. Check your API key and model in Scan settings. No leaves were added.")
        default:
            throw VerificationError.message("Gemini couldn’t finish the request (\(http.statusCode)). No leaves were added. Try again later.")
        }
    }
}

// Keep the API key and photos on the selected Google endpoint, including on redirects.
private final class NoGeminiRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
