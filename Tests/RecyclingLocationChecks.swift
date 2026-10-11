import Foundation

final class StubRecyclingMap: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@main
struct RecyclingLocationChecks {
    static func main() async throws {
        let fixture = Data(#"""
        {"elements":[
          {"type":"node","id":1,"lat":40.71,"lon":-74.0,"tags":{"amenity":"recycling","recycling_type":"container","name":"Public cans","access":"yes","recycling:cans":"yes","recycling:glass":"no","recycling:paper":"only","opening_hours":"24/7"}},
          {"type":"way","id":2,"center":{"lat":40.72,"lon":-74.0},"tags":{"amenity":"recycling","recycling_type":"centre","operator":"Community center","recycling:plastic_bottles":"yes","addr:housenumber":"12","addr:street":"Green Street","fee":"yes"}},
          {"type":"relation","id":3,"center":{"lat":40.73,"lon":-74.0},"tags":{"amenity":"recycling"}},
          {"type":"node","id":4,"lat":40.71,"lon":-74.0,"tags":{"amenity":"recycling","access":"private"}},
          {"type":"node","id":5,"lat":40.71,"lon":-74.0,"tags":{"amenity":"recycling","access":"customers"}},
          {"type":"node","id":6,"lat":40.71,"lon":-74.0,"tags":{"amenity":"recycling","disused":"yes"}},
          {"type":"node","id":7,"lat":95,"lon":-74.0,"tags":{"amenity":"recycling"}},
          {"type":"node","id":8,"tags":{"amenity":"recycling"}},
          {"type":"node","id":9,"lat":40.71,"lon":-74.0,"tags":{"amenity":"waste_basket"}},
          {"type":"node","id":1,"lat":40.71,"lon":-74.0,"tags":{"amenity":"recycling"}},
          {"type":"node","id":10,"lat":41.5,"lon":-74.0,"tags":{"amenity":"recycling"}}
        ]}
        """#.utf8)
        let decoded = try RecyclingLocation.decode(fixture)
        precondition(decoded.count == 4, "Only active, unrestricted recycling locations with valid coordinates survive")
        precondition(decoded[0].materials == ["Cans"] && decoded[0].publicAccessListed && decoded[0].hours == "24/7")
        precondition(decoded[1].materials == ["Plastic bottles"] && decoded[1].address == "12 Green Street" && decoded[1].hasFee)
        precondition(!decoded[1].publicAccessListed, "Missing access cannot be presented as confirmed public")
        precondition(decoded[2].materials.isEmpty && decoded[2].sourceURL.absoluteString.hasSuffix("relation/3"))
        for data in [Data("<html>server error</html>".utf8), Data(#"{"elements":[],"remark":"runtime error: timeout"}"#.utf8)] {
            do { _ = try RecyclingLocation.decode(data); preconditionFailure("Bad or partial response accepted") }
            catch { precondition(error is RecyclingLocationError) }
        }

        let origin = RecyclingCoordinate(latitude: 40.710456, longitude: -74.000321)
        let area = try RecyclingSearchArea(center: origin, radius: 5_000)
        precondition(area.center != origin && area.center.distance(to: origin) < 100)
        precondition(!area.query.contains("40.710456") && !area.query.contains("-74.000321"), "Precise GPS must not be uploaded")
        precondition(abs(RecyclingCoordinate(latitude: 0, longitude: 0).distance(to: .init(latitude: 0, longitude: 1)) - 111_195) < 2)
        for coordinate in [RecyclingCoordinate(latitude: .nan, longitude: 0), .init(latitude: 91, longitude: 0)] {
            do { _ = try RecyclingSearchArea(center: coordinate, radius: 5_000); preconditionFailure("Invalid area") }
            catch { precondition(error is RecyclingLocationError) }
        }
        do { _ = try RecyclingSearchArea(center: origin, radius: 1_000_000); preconditionFailure("Unbounded search") }
        catch { precondition(error is RecyclingLocationError) }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubRecyclingMap.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let service = RecyclingLocationService(session: session)
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        var requests = 0
        StubRecyclingMap.handler = { request in
            requests += 1
            precondition(request.httpMethod == "POST" && request.url?.scheme == "https")
            precondition(request.value(forHTTPHeaderField: "User-Agent")?.contains("EcoGotchi") == true)
            return (200, fixture)
        }
        let result = try await service.search(area, now: start)
        precondition(result.locations.map(\.id) == ["node/1", "way/2", "relation/3"], "Distance sorting and radius filtering")
        _ = try await service.search(area, now: start.addingTimeInterval(30))
        precondition(requests == 1, "Reopening the map uses cached data")
        StubRecyclingMap.handler = { _ in requests += 1; throw URLError(.notConnectedToInternet) }
        let stale = try await service.search(area, now: start.addingTimeInterval(1_000))
        precondition(stale.isStale && stale.fetchedAt == start && stale.locations.count == 3)
        do { _ = try await service.search(area, now: start.addingTimeInterval(90_000)); preconditionFailure("Expired fallback") }
        catch { precondition(error.localizedDescription.contains("connection")) }

        let limited = RecyclingLocationService(session: session)
        requests = 0
        StubRecyclingMap.handler = { _ in requests += 1; return (429, Data()) }
        for offset in [0.0, 10.0] {
            do { _ = try await limited.search(area, now: start.addingTimeInterval(offset)); preconditionFailure("Rate limit ignored") }
            catch { precondition(error.localizedDescription.contains("busy")) }
        }
        precondition(requests == 1, "Retry cooldown prevents hammering the public API")
        StubRecyclingMap.handler = { _ in throw URLError(.cancelled) }
        do { _ = try await RecyclingLocationService(session: session).search(area); preconditionFailure("Cancellation ignored") }
        catch { precondition(error is CancellationError) }

        let city = Data(#"""
        {"features":[
          {"attributes":{"OBJECTID":1,"Name":"Official Recycling Center","Owner":"City of Houston SWMD"},"geometry":{"x":-95.37,"y":29.76}},
          {"attributes":{"OBJECTID":2,"Name":"Private mulch vendor","Owner":"Non-City"},"geometry":{"x":-95.37,"y":29.76}}
        ]}
        """#.utf8)
        let cityLocations = try HoustonRecyclingLocations.decode(city)
        precondition(cityLocations.count == 1 && cityLocations[0].sourceName == "City of Houston")
        precondition(cityLocations[0].materials.isEmpty && !cityLocations[0].publicAccessListed, "City records must not invent materials or eligibility")
        StubRecyclingMap.handler = { request in
            if request.url?.host == "services2.arcgis.com" { return (200, city) }
            return (200, Data(#"{"elements":[]}"#.utf8))
        }
        let houston = try RecyclingSearchArea(center: .init(latitude: 29.76, longitude: -95.37), radius: 5_000)
        let supplemented = try await RecyclingLocationService(session: session).search(houston, now: start)
        precondition(supplemented.locations.count == 1 && supplemented.notice == nil)
        StubRecyclingMap.handler = { request in
            if request.url?.host == "services2.arcgis.com" { return (200, city) }
            return (503, Data())
        }
        let partial = try await RecyclingLocationService(session: session).search(houston, now: start)
        precondition(partial.locations.count == 1 && partial.notice?.contains("city drop-off") == true)

        if CommandLine.arguments.count == 3 {
            let osm = try RecyclingLocation.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            let cityLive = try HoustonRecyclingLocations.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
            print("Live fixtures decoded: \(osm.count) OSM entries and \(cityLive.count) official city facilities.")
            let near = cityLive.filter { houston.center.distance(to: $0.coordinate) <= 25_000 }
            precondition(!near.isEmpty, "Live city feed contains nearby drop-off locations")
        }
        print("Recycling map checks passed: public-access filtering, node/area parsing, material accuracy, approximate coordinates, distance ordering, caching, offline fallback, cancellation, rate limits, and city supplementation.")
    }
}
