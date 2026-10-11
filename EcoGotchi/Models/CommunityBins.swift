import Foundation
import Combine

struct BinPhoto: Codable, Equatable {
    let data: String
    let source: String
    let capturedAt: String
}

struct BinDraft: Codable, Identifiable, Equatable {
    var id = UUID().uuidString.lowercased()
    var name: String
    var notes: String
    var coordinate: RecyclingCoordinate
    var materials: [String]
    var publicAccess: Bool
    var photo: BinPhoto

    static let materials = ["Paper", "Cardboard", "Plastic", "Metal", "Glass", "Other", "Unknown"]
    func validated() throws -> Self {
        let cleanName = name.trimmingCharacters(in:.whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in:.whitespacesAndNewlines)
        guard UUID(uuidString:id) != nil, (2...80).contains(cleanName.count), cleanNotes.count <= 500,
              coordinate.isValid, !materials.isEmpty, materials.count <= 7,
              materials.allSatisfy({ Self.materials.contains($0) }), publicAccess,
              photo.source == "camera", let captured = ISO8601DateFormatter().date(from:photo.capturedAt),
              captured.timeIntervalSinceNow <= 30, photo.data.count <= 500_000,
              let jpeg = Data(base64Encoded:photo.data), jpeg.count >= 4,
              jpeg.starts(with:[0xff,0xd8]), jpeg.suffix(2) == Data([0xff,0xd9]) else {
            throw VerificationError.message("Photograph the bin, confirm public access and its position, and add a name and listed materials.")
        }
        var result = self
        result.id = id.lowercased()
        result.name = cleanName
        result.notes = cleanNotes
        result.coordinate = .init(latitude:(coordinate.latitude*100_000).rounded()/100_000,
                                  longitude:(coordinate.longitude*100_000).rounded()/100_000)
        result.materials = Array(Set(materials)).sorted()
        return result
    }
}

struct CommunityBin: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let notes: String
    let coordinate: RecyclingCoordinate
    let materials: [String]
    let community: Bool
    let isMine: Bool
    let capturedAt: String
    func validate() throws {
        guard UUID(uuidString:id) != nil, coordinate.isValid, (2...80).contains(name.count), notes.count <= 500,
              !materials.isEmpty, materials.count <= 7,
              materials.allSatisfy({ BinDraft.materials.contains($0) }), community else {
            throw VerificationError.message("The community server returned an invalid bin.")
        }
    }
}

struct SavedBin: Codable, Identifiable, Equatable {
    var draft: BinDraft
    var shared: CommunityBin?
    var server: String?
    var id: String { draft.id }
}

extension VerificationConnection {
    func binRequest(route: String, method: String = "GET", body: Data? = nil,
                    session suppliedSession: URLSession? = nil) async throws -> Data {
        guard route.hasPrefix("v1/bins") else { throw VerificationError.message("Invalid bin route.") }
        let parts = route.split(separator:"?",maxSplits:1).map(String.init)
        var components = URLComponents(url:baseURL.appendingPathComponent(parts[0]),resolvingAgainstBaseURL:false)!
        if parts.count == 2 { components.percentEncodedQuery = parts[1] }
        var request = URLRequest(url:components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.setValue(Self.installationID,forHTTPHeaderField:"X-Installation-ID")
        if let body {
            request.setValue("application/json",forHTTPHeaderField:"Content-Type")
            request.httpBody = body
        }
        let session = suppliedSession ?? URLSession(configuration:.ephemeral,delegate:NoVerificationRedirects(),delegateQueue:nil)
        defer { if suppliedSession == nil { session.invalidateAndCancel() } }
        let (data,response) = try await session.data(for:request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, data.count <= 1_000_000,
              http.url?.host == baseURL.host, http.url?.scheme == baseURL.scheme,
              http.url?.port == baseURL.port else { throw VerificationError.message("Invalid community server response.") }
        if method == "DELETE", http.statusCode == 404 { return Data() }
        guard (200...299).contains(http.statusCode) else {
            struct Failure: Decodable { let error: String }
            throw VerificationError.message((try? JSONDecoder().decode(Failure.self,from:data))?.error
                ?? "The community request failed. Your phone draft is kept.")
        }
        return data
    }
}

@MainActor
final class CommunityBinStore: ObservableObject {
    @Published private(set) var saved: [SavedBin] = []
    @Published private(set) var community: [CommunityBin] = []
    @Published private(set) var error: String?
    @Published private(set) var truncated = false
    private let fileURL: URL
    private var loadFailed = false
    private var currentOrigin: String?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("EcoGotchi/bin-landmarks.json")
        do {
            if FileManager.default.fileExists(atPath:self.fileURL.path) {
                let entries = try JSONDecoder().decode([SavedBin].self,from:Data(contentsOf:self.fileURL))
                guard entries.count <= 200, Set(entries.map(\.id)).count == entries.count else {
                    throw VerificationError.message("Invalid saved bin landmarks.")
                }
                for entry in entries { _ = try entry.draft.validated(); try entry.shared?.validate() }
                saved = entries
            }
        } catch {
            loadFailed = true
            self.error = "Saved landmarks could not be read. The file has been kept."
        }
    }

    private func commit(_ next: [SavedBin]) throws {
        guard !loadFailed, next.count <= 200 else {
            throw VerificationError.message("Could not update phone landmarks. The saved file has been kept.")
        }
        let data = try JSONEncoder().encode(next)
        try FileManager.default.createDirectory(at:fileURL.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:fileURL,options:.atomic)
        saved = next
    }

    func save(_ draft: BinDraft, game: HabitatStore, sessionID: UUID) throws {
        guard !game.isDeveloperMode, game.isCurrentSession(sessionID) else {
            throw VerificationError.message("Turn off Dev Mode to save landmarks.")
        }
        let value = try draft.validated()
        guard !saved.contains(where: { $0.id == value.id }) else { return }
        try commit(saved + [SavedBin(draft:value)])
    }

    func removePhone(_ id: String, game: HabitatStore, sessionID: UUID) throws {
        guard !game.isDeveloperMode, game.isCurrentSession(sessionID) else {
            throw VerificationError.message("The mode changed. Repeat this action in real mode.")
        }
        try commit(saved.filter { $0.id != id })
    }

    func share(_ id: String, connection: VerificationConnection, game: HabitatStore, sessionID: UUID) async throws {
        guard !game.isDeveloperMode, game.isCurrentSession(sessionID), let entry = saved.first(where: { $0.id == id }) else {
            throw VerificationError.message("Turn off Dev Mode and choose a saved phone landmark.")
        }
        let draft = try entry.draft.validated()
        let data = try await connection.binRequest(route:"v1/bins",method:"POST",body:JSONEncoder().encode(draft))
        struct Response: Decodable { let bin: CommunityBin }
        let bin = try JSONDecoder().decode(Response.self,from:data).bin
        try bin.validate()
        guard !game.isDeveloperMode, game.isCurrentSession(sessionID) else {
            throw VerificationError.message("The mode changed. Retry the same saved draft in real mode.")
        }
        var next = saved
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].shared = bin
        next[index].server = connection.baseURL.absoluteString
        try commit(next)
    }

    func removeShared(_ bin: CommunityBin, connection: VerificationConnection, game: HabitatStore, sessionID: UUID) async throws {
        guard !game.isDeveloperMode, game.isCurrentSession(sessionID), bin.isMine else {
            throw VerificationError.message("Only your own community landmarks can be removed in real mode.")
        }
        _ = try await connection.binRequest(route:"v1/bins/\(bin.id)",method:"DELETE")
        guard !game.isDeveloperMode, game.isCurrentSession(sessionID) else {
            throw VerificationError.message("The mode changed. Refresh community landmarks in real mode.")
        }
        let next = saved.map { entry -> SavedBin in
            var result = entry
            if entry.shared?.id == bin.id && entry.server == connection.baseURL.absoluteString {
                result.shared = nil; result.server = nil
            }
            return result
        }
        try commit(next)
        community.removeAll { $0.id == bin.id }
    }

    func refresh(area: RecyclingSearchArea, connection: VerificationConnection) async throws {
        let origin = connection.baseURL.absoluteString
        if currentOrigin != origin { community = []; currentOrigin = origin }
        let route = "v1/bins?latitude=\(area.latitude)&longitude=\(area.longitude)&radius=\(area.radius)"
        let data = try await connection.binRequest(route:route)
        struct Response: Decodable { let bins: [CommunityBin]; let truncated: Bool }
        let response = try JSONDecoder().decode(Response.self,from:data)
        guard response.bins.count <= 200 else { throw VerificationError.message("Invalid community map.") }
        for bin in response.bins { try bin.validate() }
        try Task.checkCancellation()
        community = response.bins
        truncated = response.truncated
    }

    func nearby(_ area: RecyclingSearchArea, origin: String?) -> [CommunityBin] {
        var results: [String: CommunityBin] = [:]
        for entry in saved where entry.server == origin {
            if let bin = entry.shared { results[bin.id] = bin }
        }
        if origin == currentOrigin { for bin in community { results[bin.id] = bin } }
        return results.values.filter { area.center.distance(to:$0.coordinate) <= Double(area.radius) }
            .sorted { area.center.distance(to:$0.coordinate) < area.center.distance(to:$1.coordinate) }
    }
}
