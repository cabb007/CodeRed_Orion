import SwiftUI
import MapKit

struct CommunityLandmarksView: View {
    @ObservedObject var bins: CommunityBinStore
    let area: RecyclingSearchArea?
    @EnvironmentObject private var game: HabitatStore
    @State private var showNew = false
    @State private var showConnection = false
    @State private var pendingShare: String?
    @State private var operation: Task<Void,Never>?
    @State private var busy = false
    @State private var notice: String?
    @State private var origin = VerificationConnection.savedURL

    private var nearby: [CommunityBin] { area.map { bins.nearby($0,origin:origin) } ?? [] }
    private var drafts: [SavedBin] {
        bins.saved.filter { entry in
            let inArea = area.map { $0.center.distance(to:entry.draft.coordinate) <= Double($0.radius) } ?? true
            return inArea && (entry.shared == nil || entry.server != origin)
        }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Photo bin landmarks").font(.headline)
            Button("Add a bin landmark") { showNew = true }.buttonStyle(.bordered)
                .disabled(game.isDeveloperMode || busy)
            Button("Community map connection") { showConnection = true }.buttonStyle(.bordered)
                .disabled(game.isDeveloperMode || busy)
            if game.isDeveloperMode {
                Text("Turn Dev Mode off to create, share or remove saved landmarks.").font(.caption)
            }
            if area != nil {
                Button("Refresh community landmarks") { refresh() }.buttonStyle(.bordered)
                    .disabled(busy || game.isDeveloperMode || !VerificationConnection.isConfigured)
            }
            if busy { ProgressView() }
            if let notice { Text(notice).font(.caption).accessibilityAddTraits(.updatesFrequently) }
            if let error = bins.error { Text(error).font(.caption).foregroundStyle(.red) }
            ForEach(drafts) { entry in
                VStack(alignment:.leading,spacing:10) {
                    Text(entry.draft.name).font(.subheadline.bold())
                    Text("On this phone · unverified").font(.caption)
                    Text(entry.draft.materials.joined(separator:" · ")).font(.caption)
                    if !entry.draft.notes.isEmpty { Text(entry.draft.notes).font(.caption) }
                    if let data = Data(base64Encoded:entry.draft.photo.data), let image = UIImage(data:data) {
                        Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:180)
                    }
                    Button("Directions") { directions(entry.draft.coordinate,name:entry.draft.name) }
                    Button("Share with community…") { pendingShare = entry.id }
                        .disabled(game.isDeveloperMode || busy || !VerificationConnection.isConfigured)
                    Button("Remove phone draft",role:.destructive) {
                        run { try bins.removePhone(entry.id,game:game,sessionID:game.modeSessionID) }
                    }.disabled(game.isDeveloperMode || busy)
                }.padding(14).pixelPanel(Palette.paper,shadow:false)
            }
            ForEach(nearby) { bin in
                CommunityBinCard(bin:bin,bins:bins,cached:!bins.community.contains(where: { $0.id == bin.id }),
                    disabled:busy,onRemove:{
                        let modeID = game.modeSessionID
                        run { try await bins.removeShared(bin,connection:VerificationConnection.current(),game:game,sessionID:modeID) }
                    },onDirections:{ directions(bin.coordinate,name:bin.name) })
                    .id(bin.id + origin)
            }
            if bins.truncated { Text("The community server returned its first 200 nearby landmarks.").font(.caption) }
            Text("Blue pins are phone drafts. Purple pins are unverified community landmarks. Sharing is optional and does not award leaves.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .sheet(isPresented:$showNew) { NewBinView(bins:bins) }
        .sheet(isPresented:$showConnection,onDismiss:{ origin = VerificationConnection.savedURL }) { CommunityConnectionView() }
        .confirmationDialog("Share this photo, exact bin location, name and notes with everyone using your connected server?",
            isPresented:Binding(get:{ pendingShare != nil },set:{ if !$0 { pendingShare = nil } }),titleVisibility:.visible) {
                Button("Share with community") {
                    guard let id = pendingShare else { return }
                    let modeID = game.modeSessionID
                    pendingShare = nil
                    run { try await bins.share(id,connection:VerificationConnection.current(),game:game,sessionID:modeID) }
                }
                Button("Cancel",role:.cancel) { pendingShare = nil }
            }
        .task(id:"\(area?.latitude ?? 0)-\(area?.longitude ?? 0)-\(area?.radius ?? 0)-\(origin)-\(game.modeSessionID)") {
            guard let area, !game.isDeveloperMode, VerificationConnection.isConfigured else { return }
            do { try await bins.refresh(area:area,connection:VerificationConnection.current()); notice = nil }
            catch is CancellationError { }
            catch { notice = "Could not refresh community landmarks. Phone drafts and labeled cached landmarks remain available." }
        }
        .onChange(of:game.modeSessionID) { _,_ in operation?.cancel(); busy = false; pendingShare = nil; showConnection = false; showNew = false }
        .onDisappear { operation?.cancel() }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy, !game.isDeveloperMode else { return }
        busy = true; notice = nil
        operation = Task { @MainActor in
            defer { busy = false }
            do { try await action(); try Task.checkCancellation(); notice = "Landmarks updated." }
            catch is CancellationError { }
            catch { notice = error.localizedDescription }
        }
    }
    private func refresh() {
        guard let area else { return }
        run { try await bins.refresh(area:area,connection:VerificationConnection.current()) }
    }
    private func directions(_ coordinate: RecyclingCoordinate,name:String) {
        let item = MKMapItem(placemark:MKPlacemark(coordinate:.init(latitude:coordinate.latitude,longitude:coordinate.longitude)))
        item.name = name
        item.openInMaps(launchOptions:[MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDefault])
    }
}

private struct CommunityBinCard: View {
    let bin: CommunityBin
    @ObservedObject var bins: CommunityBinStore
    let cached: Bool
    let disabled: Bool
    let onRemove: () -> Void
    let onDirections: () -> Void
    @EnvironmentObject private var game: HabitatStore
    @State private var image: UIImage?
    @State private var error: String?
    @State private var photoTask: Task<Void,Never>?
    @State private var loading = false
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text(bin.name).font(.subheadline.bold())
            Text(cached ? "Community · phone cache · unverified" : "Community · unverified").font(.caption)
            Text(bin.materials.joined(separator:" · ")).font(.caption)
            if !bin.notes.isEmpty { Text(bin.notes).font(.caption) }
            if let image { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:180) }
            else {
                Button(loading ? "Loading photo…" : "View bin photo") { loadPhoto() }.disabled(loading || game.isDeveloperMode)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            Button("Directions",action:onDirections)
            if bin.isMine { Button("Remove my shared landmark",role:.destructive,action:onRemove).disabled(disabled || game.isDeveloperMode) }
        }.padding(14).pixelPanel(Palette.paper,shadow:false)
            .onDisappear { photoTask?.cancel() }
            .onChange(of:game.modeSessionID) { _,_ in photoTask?.cancel() }
    }
    private func loadPhoto() {
        if let saved = bins.saved.first(where: { $0.shared?.id == bin.id && $0.server == VerificationConnection.savedURL }),
           let data = Data(base64Encoded:saved.draft.photo.data) {
            image = UIImage(data:data); return
        }
        guard !game.isDeveloperMode else { return }
        loading = true; error = nil
        photoTask = Task { @MainActor in
            defer { loading = false }
            do {
                let data = try await VerificationConnection.current().binRequest(route:"v1/bins/\(bin.id)/photo")
                struct Photo: Decodable { let mimeType: String; let data: String }
                let response = try JSONDecoder().decode(Photo.self,from:data)
                guard response.mimeType == "image/jpeg", let jpeg = Data(base64Encoded:response.data), jpeg.count <= 375_000,
                      let photo = UIImage(data:jpeg) else { throw VerificationError.message("Invalid bin photo.") }
                try Task.checkCancellation()
                image = photo
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}

private struct CommunityConnectionView: View {
    @EnvironmentObject private var game: HabitatStore
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var token = ""
    @State private var error: String?
    @State private var modeID: UUID?
    var body: some View {
        NavigationStack {
            Form {
                Text("Connect to your Recycli server to share bin landmarks. AI review and a Gemini key are not required. The connection is shared with Scan settings.")
                    .font(.caption)
                TextField("HTTPS server origin",text:$address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                SecureField("Server access token",text:$token).textInputAutocapitalization(.never).autocorrectionDisabled()
                if let error { Text(error).foregroundStyle(.red) }
                Button("Save connection") {
                    do {
                        guard modeID == game.modeSessionID, !game.isDeveloperMode else { return }
                        try VerificationConnection(address:address,token:token).save()
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.disabled(game.isDeveloperMode)
            }.navigationTitle("Community connection").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Cancel") { dismiss() } }
        }.task {
            guard !game.isDeveloperMode else { dismiss(); return }
            modeID = game.modeSessionID
            address = VerificationConnection.savedURL
            token = VerificationConnection.savedToken
        }
        .onChange(of:game.modeSessionID) { _,_ in token = ""; dismiss() }
    }
}
