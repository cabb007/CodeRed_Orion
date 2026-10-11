import Foundation

struct RecyclingCoordinate: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
    var approximate: Self { .init(latitude: (latitude * 1_000).rounded() / 1_000, longitude: (longitude * 1_000).rounded() / 1_000) }

    func distance(to other: Self) -> Double {
        let radians = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * radians / 2), 2)
            + cos(latitude * radians) * cos(other.latitude * radians) * pow(sin((other.longitude - longitude) * radians / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, a))))
    }
}

struct RecyclingSearchArea: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let radius: Int
    var center: RecyclingCoordinate { .init(latitude: latitude, longitude: longitude) }

    init(center: RecyclingCoordinate, radius: Int) throws {
        guard center.isValid, [5_000, 10_000, 25_000].contains(radius) else { throw RecyclingLocationError.invalidArea }
        // About 100 m precision; exact GPS coordinates never go to Overpass.
        let approximate = center.approximate
        latitude = approximate.latitude
        longitude = approximate.longitude
        self.radius = radius
    }

    var query: String {
        """
        [out:json][timeout:20][maxsize:16777216];
        nwr["amenity"="recycling"](around:\(radius),\(latitude),\(longitude));
        out center tags;
        """
    }
}

struct RecyclingLocation: Identifiable, Sendable {
    let id: String
    let coordinate: RecyclingCoordinate
    let name: String
    let kind: String
    let materials: [String]
    let address: String?
    let hours: String?
    let publicAccessListed: Bool
    let hasFee: Bool
    let sourceURL: URL
    var sourceName = "OpenStreetMap"

    static func decode(_ data: Data) throws -> [Self] {
        let response: OverpassResponse
        do { response = try JSONDecoder().decode(OverpassResponse.self, from: data) }
        catch { throw RecyclingLocationError.invalidResponse }
        // An Overpass timeout can return HTTP 200 with partial results and a remark.
        guard response.remark?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
            throw RecyclingLocationError.busy
        }
        var seen = Set<String>()
        return response.elements.compactMap { element in
            guard let tags = element.tags, tags["amenity"] == "recycling",
                  ["node", "way", "relation"].contains(element.type), element.id > 0 else { return nil }
            let access = tags["access"]?.lowercased()
            // Unknown access remains clearly labeled; explicitly restricted sites are omitted.
            if let access, !["yes", "public", "permissive", "designated"].contains(access) { return nil }
            if ["yes", "true", "1"].contains(tags["disused"] ?? "") || ["yes", "true", "1"].contains(tags["abandoned"] ?? "") { return nil }
            let coordinate: RecyclingCoordinate
            if let lat = element.lat, let lon = element.lon { coordinate = .init(latitude: lat, longitude: lon) }
            else if let center = element.center { coordinate = .init(latitude: center.lat, longitude: center.lon) }
            else { return nil }
            guard coordinate.isValid else { return nil }
            let id = "\(element.type)/\(element.id)"
            guard seen.insert(id).inserted, let url = URL(string: "https://www.openstreetmap.org/\(id)") else { return nil }
            let kind: String
            switch tags["recycling_type"] {
            case "container", "bin": kind = "Recycling bin"
            case "centre": kind = "Drop-off center"
            case "reverse_vending_machine": kind = "Bottle & can return"
            default: kind = "Recycling point"
            }
            let materials = Set(tags.compactMap { key, value -> String? in
                guard key.hasPrefix("recycling:"), value.lowercased() == "yes" else { return nil }
                let material = String(key.dropFirst("recycling:".count))
                guard !material.contains(":"), !material.isEmpty else { return nil }
                return materialNames[material] ?? material.replacingOccurrences(of: "_", with: " ").capitalized
            }).sorted()
            let street = [tags["addr:housenumber"], tags["addr:street"]].compactMap { $0 }.joined(separator: " ")
            let address = tags["addr:full"] ?? [street, tags["addr:city"] ?? "", tags["addr:postcode"] ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
            return Self(id: id, coordinate: coordinate, name: nonempty(tags["name"]) ?? nonempty(tags["operator"]) ?? kind,
                        kind: kind, materials: materials, address: nonempty(address), hours: nonempty(tags["opening_hours"]),
                        publicAccessListed: access != nil, hasFee: tags["fee"] == "yes", sourceURL: url)
        }
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private static let materialNames = [
        "cans": "Cans", "aluminium": "Aluminum", "aluminum": "Aluminum", "metal": "Metal", "scrap_metal": "Scrap metal",
        "paper": "Paper", "cardboard": "Cardboard", "cartons": "Cartons", "beverage_cartons": "Drink cartons",
        "glass": "Glass", "glass_bottles": "Glass bottles & jars", "plastic": "Plastic", "plastic_bottles": "Plastic bottles",
        "plastic_packaging": "Plastic packaging", "plastic_bags": "Plastic bags", "batteries": "Household batteries",
        "electrical_appliances": "Electronics", "small_electrical_appliances": "Small electronics", "clothes": "Clothing",
        "shoes": "Shoes", "organic": "Organic waste", "green_waste": "Garden waste", "food_waste": "Food scraps"
    ]
}

private struct OverpassResponse: Decodable {
    let elements: [Element]
    let remark: String?
    struct Element: Decodable {
        let type: String
        let id: Int64
        let lat: Double?
        let lon: Double?
        let center: Center?
        let tags: [String: String]?
    }
    struct Center: Decodable { let lat: Double; let lon: Double }
}

enum RecyclingLocationError: LocalizedError {
    case invalidArea, invalidResponse, busy, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidArea: "Choose a location and try again."
        case .invalidResponse: "The recycling map sent an unreadable response. Try again shortly."
        case .busy: "The recycling map is busy. Wait a minute, then try again."
        case .unavailable: "Couldn’t load recycling locations. Check your connection and try again."
        }
    }
}

struct RecyclingSearchResult: Sendable {
    let locations: [RecyclingLocation]
    let fetchedAt: Date
    let isStale: Bool
    var notice: String? = nil
}

actor RecyclingLocationService {
    static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!
    private let session: URLSession
    private let endpoint: URL
    private var cache: [RecyclingSearchArea: RecyclingSearchResult] = [:]
    private var retryAfter = Date.distantPast
    private var cityCache: (date: Date, locations: [RecyclingLocation])?

    init(session: URLSession = .shared, endpoint: URL = RecyclingLocationService.endpoint) {
        self.session = session
        self.endpoint = endpoint
    }

    func search(_ area: RecyclingSearchArea, now: Date = Date()) async throws -> RecyclingSearchResult {
        if let saved = cache[area], saved.notice == nil, now.timeIntervalSince(saved.fetchedAt) < 900 { return saved }
        do {
            var locations: [RecyclingLocation] = []
            var communityError: Error?
            var notice: String?
            do { locations = try await communityLocations(area, now: now) }
            catch {
                try Task.checkCancellation()
                if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
                communityError = error
            }
            let houston = RecyclingCoordinate(latitude: 29.760, longitude: -95.370)
            if area.center.distance(to: houston) < 120_000 {
                do {
                    let city = try await houstonLocations(now: now)
                    for location in city {
                        // OSM may already describe the same center with richer material details.
                        if locations.contains(where: { $0.kind == "Drop-off center" && $0.coordinate.distance(to: location.coordinate) < 150 }) { continue }
                        locations.append(location)
                    }
                    if communityError != nil { notice = "Public bin data couldn’t load. Showing city drop-off locations only. Try again to refresh." }
                } catch {
                    try Task.checkCancellation()
                    if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
                    if let communityError { throw communityError }
                    notice = "City drop-off data couldn’t load. Showing community-mapped locations only."
                }
            } else if let communityError { throw communityError }
            try Task.checkCancellation()
            locations = locations.filter { area.center.distance(to: $0.coordinate) <= Double(area.radius) }
                .sorted { area.center.distance(to: $0.coordinate) < area.center.distance(to: $1.coordinate) }
            let result = RecyclingSearchResult(locations: locations, fetchedAt: now, isStale: false, notice: notice)
            cache[area] = result
            if cache.count > 8, let oldest = cache.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key { cache.removeValue(forKey: oldest) }
            return result
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            if let saved = cache[area], now.timeIntervalSince(saved.fetchedAt) < 86_400 {
                return RecyclingSearchResult(locations: saved.locations, fetchedAt: saved.fetchedAt, isStale: true, notice: saved.notice)
            }
            if let error = error as? RecyclingLocationError { throw error }
            throw RecyclingLocationError.unavailable
        }
    }

    private func communityLocations(_ area: RecyclingSearchArea, now: Date) async throws -> [RecyclingLocation] {
        guard now >= retryAfter else { throw RecyclingLocationError.busy }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("EcoGotchi/1.0 (iOS recycling locator)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [URLQueryItem(name: "data", value: area.query)]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw RecyclingLocationError.invalidResponse }
        if http.statusCode == 429 || (500...599).contains(http.statusCode) {
            let seconds = min(300, max(60, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60))
            retryAfter = now.addingTimeInterval(seconds)
            throw RecyclingLocationError.busy
        }
        guard http.statusCode == 200 else { throw RecyclingLocationError.unavailable }
        guard data.count <= 5_000_000 else { throw RecyclingLocationError.invalidResponse }
        do { return try RecyclingLocation.decode(data) }
        catch RecyclingLocationError.busy {
            retryAfter = now.addingTimeInterval(60)
            throw RecyclingLocationError.busy
        }
    }

    private func houstonLocations(now: Date) async throws -> [RecyclingLocation] {
        if let cityCache, now.timeIntervalSince(cityCache.date) < 86_400 { return cityCache.locations }
        let url = URL(string: "https://services2.arcgis.com/LYMgRMwHfrWWEg3s/ArcGIS/rest/services/City_of_Houston_SWMD_Recycling_Disposal_Facilities/FeatureServer/0/query?where=1%3D1&outFields=OBJECTID,Name,Owner&outSR=4326&f=json")!
        let (data, response) = try await session.data(for: URLRequest(url: url, timeoutInterval: 15))
        try Task.checkCancellation()
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 1_000_000 else { throw RecyclingLocationError.unavailable }
        let locations = try HoustonRecyclingLocations.decode(data)
        cityCache = (now, locations)
        return locations
    }
}

enum HoustonRecyclingLocations {
    static func decode(_ data: Data) throws -> [RecyclingLocation] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.exceededTransferLimit != true else { throw RecyclingLocationError.invalidResponse }
        var seen = Set<Int>()
        return response.features.compactMap { feature in
            let attributes = feature.attributes
            guard attributes.Owner == "City of Houston SWMD", let name = attributes.Name,
                  !name.isEmpty, seen.insert(attributes.OBJECTID).inserted, let geometry = feature.geometry else { return nil }
            let coordinate = RecyclingCoordinate(latitude: geometry.y, longitude: geometry.x)
            guard coordinate.isValid else { return nil }
            return RecyclingLocation(id: "houston/\(attributes.OBJECTID)", coordinate: coordinate, name: name,
                                     kind: name.localizedCaseInsensitiveContains("reuse") ? "Reuse drop-off" : "Drop-off center",
                                     materials: [], address: nil, hours: nil, publicAccessListed: false, hasFee: false,
                                     sourceURL: URL(string: "https://www.houstontx.gov/solidwaste/recycling_map.html")!, sourceName: "City of Houston")
        }
    }
    private struct Response: Decodable {
        let features: [Feature]
        let exceededTransferLimit: Bool?
    }
    private struct Feature: Decodable {
        let attributes: Attributes
        let geometry: Geometry?
    }
    private struct Attributes: Decodable { let OBJECTID: Int; let Name: String?; let Owner: String? }
    private struct Geometry: Decodable { let x: Double; let y: Double }
}
