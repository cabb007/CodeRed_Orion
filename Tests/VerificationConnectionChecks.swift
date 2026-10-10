import Foundation

final class StubConnection: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@main
struct VerificationConnectionChecks {
    static func main() async throws {
        for host in ["10.0.0.5", "172.20.10.2", "192.168.1.10", "169.254.10.2", "test-mac.local"] {
            precondition(VerificationConnection.allowsLocalHTTP(host: host, directURL: nil))
            _ = try VerificationConnection(address: "http://\(host):8787", token: "test-server-access-token-123456")
        }
        for host in ["192.0.0.2", "192.168.1.256", "192.168.01.2", "172.32.1.2", "10.0.1", "10.evil.example", "8.8.8.8", "example.com", "[2001:db8::4]"] {
            precondition(!VerificationConnection.allowsLocalHTTP(host: host, directURL: nil), "Unexpected HTTP host allowed: \(host)")
        }
        let configured = "http://[2001:db8::4]:8787"
        precondition(VerificationConnection.allowsLocalHTTP(host: URL(string: configured)!.host!, directURL: configured))
        precondition(!VerificationConnection.allowsLocalHTTP(host: "[2001:db8::5]", directURL: configured))
        let connection = try VerificationConnection(address: "http://test-mac.local:8787", token: "test-server-access-token-123456")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubConnection.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        StubConnection.handler = { request in
            precondition(request.url?.path == "/v1/status" && request.httpMethod == "GET")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-server-access-token-123456")
            precondition(request.httpBody == nil && request.httpBodyStream == nil, "Connection tests never upload photos")
            return (200, Data(#"{"service":"ecogotchi","status":"ok","reviewsRemaining":30}"#.utf8))
        }
        let status = try await connection.testConnection(session: session)
        precondition(status.reviewsRemaining == 30)
        for (code, body, message) in [
            (401, "{}", "token didn’t match"),
            (404, "{}", "Restart"),
            (200, "<html>Another service</html>", "valid EcoGotchi"),
            (200, #"{"service":"other","status":"ok","reviewsRemaining":30}"#, "valid EcoGotchi"),
            (200, #"{"service":"ecogotchi","status":"ok","reviewsRemaining":-1}"#, "valid EcoGotchi")
        ] {
            StubConnection.handler = { _ in (code, Data(body.utf8)) }
            do {
                _ = try await connection.testConnection(session: session)
                preconditionFailure("Invalid connection test passed")
            } catch { precondition(error.localizedDescription.contains(message), error.localizedDescription) }
        }
        for (code, message) in [(URLError.cannotFindHost, ".local address"), (.cannotConnectToHost, "server running"),
                                (.notConnectedToInternet, "Local Network"), (.timedOut, "timed out")] {
            StubConnection.handler = { _ in throw URLError(code) }
            do {
                _ = try await connection.testConnection(session: session)
                preconditionFailure("Unreachable server passed")
            } catch { precondition(error.localizedDescription.contains(message), error.localizedDescription) }
        }
        print("Connection checks passed: authenticated photo-free request, server identity, invalid responses, and network guidance.")
    }
}
