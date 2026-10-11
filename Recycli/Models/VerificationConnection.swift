import Foundation
import Security

struct VerificationConnection {
    let baseURL: URL
    let token: String

    static var savedURL: String { UserDefaults.standard.string(forKey: "ecogotchi.verification.url") ?? "" }
    // A development fallback for the Mac's current network; update when its address changes.
    static var configuredDirectURL: String? { Bundle.main.object(forInfoDictionaryKey: "RecycliLocalServerURL") as? String }

    static func allowsLocalHTTP(host: String, directURL: String? = configuredDirectURL) -> Bool {
        let host = host.lowercased()
        if host.hasSuffix(".local") || host == "localhost" { return true }
        let pieces = host.split(separator: ".", omittingEmptySubsequences: false)
        if pieces.count == 4 {
            let bytes = pieces.compactMap { Int($0) }
            if bytes.count == 4 && zip(pieces, bytes).allSatisfy({ String($0.1) == $0.0 && (0...255).contains($0.1) }) {
                return bytes[0] == 10 || (bytes[0] == 172 && (16...31).contains(bytes[1])) ||
                    (bytes[0] == 192 && bytes[1] == 168) || (bytes[0] == 169 && bytes[1] == 254)
            }
        }
        // The hotspot can assign a global IPv6 address. Allow only the explicitly configured
        // Mac address, whose matching ATS exception is in Info.plist, rather than all public IPs.
        guard host.contains(":"), let directURL, let configured = URL(string: directURL),
              configured.scheme == "http" else { return false }
        return host == configured.host?.lowercased()
    }
    private static let service = "org.ecogotchi.verification"
    private static let account = "server-access-token"
    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    static var savedToken: String {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static var isConfigured: Bool { (try? current()) != nil }
    static func current() throws -> Self { try .init(address: savedURL, token: savedToken) }

    init(address: String, token: String) throws {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              url.scheme == "https" || (url.scheme == "http" && Self.allowsLocalHTTP(host: host)) else {
            throw VerificationError.message("Enter an HTTPS server address, your Mac’s .local address, or its private IPv4 address with port 8787. On a hotspot, try Use this Mac’s direct address. Don’t include a path.")
        }
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanToken.count >= 24 else { throw VerificationError.message("Enter the server access token (at least 24 characters). This is different from your Gemini API key.") }
        #if os(iOS) && !targetEnvironment(simulator)
        guard host != "localhost" && host != "127.0.0.1" && host != "[::1]" else {
            throw VerificationError.message("On an iPhone, localhost points to the phone. Enter your Mac’s .local address instead, with both devices on the same Wi-Fi.")
        }
        #endif
        baseURL = url
        self.token = cleanToken
    }

    func save() throws {
        let value = Data(token.utf8)
        var query = Self.keychainQuery
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = value
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw VerificationError.message("The access token couldn’t be saved securely. Try again.") }
        UserDefaults.standard.set(baseURL.absoluteString, forKey: "ecogotchi.verification.url")
    }

    static var installationID: String {
        let key = "ecogotchi.verification.installation"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    struct ConnectionStatus: Decodable {
        let service: String
        let status: String
        let reviewsRemaining: Int
        let communityBins: Bool?
        let aiReview: Bool?
    }

    // Tests the phone-to-server connection and access token without photos or AI tokens.
    func testConnection(session suppliedSession: URLSession? = nil) async throws -> ConnectionStatus {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/status"))
        request.timeoutInterval = 12
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let session = suppliedSession ?? URLSession(configuration: .ephemeral, delegate: NoVerificationRedirects(), delegateQueue: nil)
        defer { if suppliedSession == nil { session.invalidateAndCancel() } }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            throw VerificationError.message(Self.connectionError(error))
        }
        guard let http = response as? HTTPURLResponse else {
            throw VerificationError.message("This address didn’t return a Recycli server response.")
        }
        if http.statusCode == 401 {
            throw VerificationError.message("The Mac responded, but the access token didn’t match. Copy RECYCLI_ACCESS_TOKEN from server/.env, not GEMINI_API_KEY.")
        }
        if http.statusCode == 404 {
            throw VerificationError.message("This server doesn’t have the connection test yet. Restart the updated Recycli server on your Mac and try again.")
        }
        guard http.statusCode == 200,
              let result = try? JSONDecoder().decode(ConnectionStatus.self, from: data),
              ["recycli", "ecogotchi"].contains(result.service), result.status == "ok", result.reviewsRemaining >= 0 else {
            throw VerificationError.message("This address didn’t return a valid Recycli connection check. Check the server address and port.")
        }
        return result
    }

    static func connectionError(_ error: Error) -> String {
        switch (error as? URLError)?.code {
        case .cannotFindHost, .dnsLookupFailed:
            return "Couldn’t find your Mac’s .local address. In AI connection settings, try Use this Mac’s direct address. Keep the Mac connected to your iPhone’s hotspot or the same Wi-Fi, and allow Recycli’s Local Network access."
        case .cannotConnectToHost:
            return "Found the address but couldn’t connect. Keep the Recycli server running on your Mac with HOST=:: and port 8787 so both IPv4 and IPv6 can connect. Check that the Mac firewall allows it."
        case .notConnectedToInternet, .dataNotAllowed:
            return "No connection to the server. Connect to the same Wi-Fi as your Mac and enable Local Network for Recycli in iPhone Settings."
        case .timedOut:
            return "The request timed out. Keep your Mac awake and check that both devices can communicate on the same Wi-Fi. If this was a review, retry the same photos."
        case .appTransportSecurityRequiresSecureConnection:
            return "iOS blocked this connection. Use HTTPS for a hosted server, or your Mac’s http://name.local:8787 address for a local demo."
        default:
            return "Couldn’t reach the review server. Keep the Mac awake, use the same Wi-Fi, and enable Local Network for Recycli in iPhone Settings."
        }
    }

    func assess(_ submission: RecyclingSubmission) async throws -> RecyclingAssessment {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/recycling/verify"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.installationID, forHTTPHeaderField: "X-Installation-ID")
        request.httpBody = try JSONEncoder().encode(submission)
        let session = URLSession(configuration: .ephemeral, delegate: NoVerificationRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            throw VerificationError.message(Self.connectionError(error))
        }
        guard let http = response as? HTTPURLResponse else { throw VerificationError.message("The server sent an invalid response.") }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 {
                throw VerificationError.message("The server access token didn’t match. Open AI connection settings and use RECYCLI_ACCESS_TOKEN from server/.env, not the Gemini key.")
            }
            struct Failure: Decodable { let error: String }
            let failure = try? JSONDecoder().decode(Failure.self, from: data)
            throw VerificationError.message(failure?.error ?? "The review couldn’t finish. No leaves were added. Try again.")
        }
        guard let result = try? JSONDecoder().decode(RecyclingAssessment.self, from: data),
              result.submissionId == submission.submissionId,
              result.status == .approved ? result.isValidReward : (result.leaves == 0 && result.cleanup == 0) else {
            throw VerificationError.message("The server returned an incomplete review. No leaves were added.")
        }
        return result
    }
}

// Do not forward photos or the access token to a redirected destination.
final class NoVerificationRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
