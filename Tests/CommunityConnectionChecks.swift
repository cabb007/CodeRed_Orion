import Foundation

final class BinProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int,Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status,data) = try Self.handler(request)
            let response = HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:"HTTP/1.1",headerFields:nil)!
            client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() {}
}

@main
struct CommunityConnectionChecks {
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BinProtocol.self]
        let session = URLSession(configuration:configuration)
        defer { session.invalidateAndCancel() }
        let connection = try VerificationConnection(address:"https://bins.example",token:String(repeating:"x",count:24))
        BinProtocol.handler = { request in
            precondition(request.url!.path == "/v1/bins")
            precondition(request.value(forHTTPHeaderField:"Authorization") == "Bearer " + String(repeating:"x",count:24))
            precondition(UUID(uuidString:request.value(forHTTPHeaderField:"X-Installation-ID")!) != nil)
            precondition(request.httpBody == nil)
            let query = URLComponents(url:request.url!,resolvingAgainstBaseURL:false)!.queryItems!
            precondition(query.contains { $0.name == "radius" && $0.value == "5000" })
            return (200,Data("{\"bins\":[],\"truncated\":false}".utf8))
        }
        let data = try await connection.binRequest(route:"v1/bins?latitude=29&longitude=-95&radius=5000",session:session)
        precondition(String(data:data,encoding:.utf8)!.contains("bins"))
        BinProtocol.handler = { _ in (403,Data("{\"error\":\"Only the owner can remove this bin.\"}".utf8)) }
        do {
            _ = try await connection.binRequest(route:"v1/bins/00000000-0000-0000-0000-000000000001",method:"DELETE",session:session)
            preconditionFailure("Ownership error ignored")
        } catch { precondition(error.localizedDescription.contains("owner")) }
        BinProtocol.handler = { _ in (404,Data()) }
        _ = try await connection.binRequest(route:"v1/bins/00000000-0000-0000-0000-000000000001",method:"DELETE",session:session)
        BinProtocol.handler = { _ in (302,Data()) }
        do {
            _ = try await connection.binRequest(route:"v1/bins",session:session)
            preconditionFailure("Redirect accepted")
        } catch { }
        print("Community connection checks passed")
    }
}
