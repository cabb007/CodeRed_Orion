import SwiftUI
import MapKit
import CoreLocation
import Combine

@MainActor
final class BinLocationPicker: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var coordinate: RecyclingCoordinate?
    @Published var message: String?
    @Published var busy = false
    private let manager = CLLocationManager()
    private var timeout: Task<Void, Never>?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyBest }
    func locate() { busy = true; message = nil; authorize() }
    private func authorize() {
        guard busy else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
            timeout?.cancel()
            timeout = Task { try? await Task.sleep(for:.seconds(18)); if !Task.isCancelled { self.fail() } }
        default: fail()
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { authorize() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard busy, let value = locations.last(where: { $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 120 }) else { return }
        coordinate = .init(latitude:value.coordinate.latitude,longitude:value.coordinate.longitude)
        cancel()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { if busy { fail() } }
    private func fail() { cancel(); message = "Location is unavailable. Enter coordinates or enable Location in Settings." }
    func cancel() { busy = false; manager.stopUpdatingLocation(); timeout?.cancel() }
}

struct NewBinView: View {
    @ObservedObject var bins: CommunityBinStore
    @EnvironmentObject private var game: HabitatStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var camera = RecyclingCamera()
    @StateObject private var locator = BinLocationPicker()
    @State private var modeID: UUID?
    @State private var photo: BinPhoto?
    @State private var name = ""
    @State private var notes = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var coordinate: RecyclingCoordinate?
    @State private var confirmed = false
    @State private var publicAccess = false
    @State private var materials: Set<String> = ["Unknown"]
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Bin photo") {
                    Text("Photograph a public bin and its sorting label. Avoid people and private spaces. Taking a photo does not upload it.")
                        .font(.caption)
                    if let photo, let data = Data(base64Encoded:photo.data), let image = UIImage(data:data) {
                        Image(uiImage:image).resizable().scaledToFit().frame(height:180)
                        Button("Retake") { self.photo = nil; camera.start() }
                    } else {
                        RecyclingCameraPreview(session:camera.session).frame(height:220)
                        if let message = camera.message { Text(message).font(.caption) }
                        Button(camera.ready ? "Photograph bin" : "Allow camera / try again") {
                            if camera.ready { camera.capture { preparePhoto($0,at:$1) } } else { camera.start() }
                        }.disabled(camera.capturing || camera.starting)
                    }
                }
                Section("Position the bin") {
                    Button(locator.busy ? "Finding location…" : "Use my location") { locator.locate() }.disabled(locator.busy)
                    if let message = locator.message { Text(message).font(.caption) }
                    TextField("Latitude",text:$latitude).keyboardType(.numbersAndPunctuation)
                        .onChange(of:latitude) { _,_ in confirmed = false }
                    TextField("Longitude",text:$longitude).keyboardType(.numbersAndPunctuation)
                        .onChange(of:longitude) { _,_ in confirmed = false }
                    Button("Apply coordinates") { applyCoordinates() }
                    if let coordinate {
                        MapReader { proxy in
                            Map(position:$mapPosition) {
                                Marker("Your bin",coordinate:.init(latitude:coordinate.latitude,longitude:coordinate.longitude)).tint(.blue)
                            }.frame(height:220)
                                .onTapGesture(coordinateSpace:.local) { point in
                                    if let value = proxy.convert(point,from:.local) {
                                        setCoordinate(.init(latitude:value.latitude,longitude:value.longitude))
                                    }
                                }
                        }
                        Text("Tap the map to move the pin to the bin itself.").font(.caption)
                    }
                    Toggle("I confirm this pin marks the bin",isOn:$confirmed).disabled(coordinate == nil)
                }
                Section("Landmark details") {
                    TextField("Name (2–80 characters)",text:$name)
                    TextField("Notes (up to 500 characters)",text:$notes,axis:.vertical)
                    ForEach(BinDraft.materials,id:\.self) { material in
                        Toggle(material,isOn:Binding(get:{ materials.contains(material) },set:{ enabled in
                            if enabled {
                                if material == "Unknown" { materials = ["Unknown"] }
                                else { materials.remove("Unknown"); materials.insert(material) }
                            } else { materials.remove(material) }
                        }))
                    }
                    Toggle("This bin is publicly accessible",isOn:$publicAccess)
                    Text("Save on this phone first. Sharing later publishes the photo, exact position, name and notes to other people using your community server. Bin landmarks do not earn leaves.")
                        .font(.caption)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Button("Save landmark on this phone") { save() }
                    .disabled(photo == nil || !confirmed || !publicAccess || game.isDeveloperMode)
            }
            .navigationTitle("Add a bin landmark").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
        .task { modeID = game.modeSessionID }
        .onChange(of:locator.coordinate) { _,value in if let value { setCoordinate(value) } }
        .onChange(of:game.modeSessionID) { _,_ in camera.stop(); locator.cancel(); dismiss() }
        .onChange(of:phase) { _,value in if value != .active { camera.stop(); locator.cancel() } }
        .onDisappear { camera.stop(); locator.cancel() }
    }
    private func setCoordinate(_ value: RecyclingCoordinate) {
        coordinate = .init(latitude:(value.latitude*100_000).rounded()/100_000,longitude:(value.longitude*100_000).rounded()/100_000)
        latitude = String(format:"%.5f",value.latitude)
        longitude = String(format:"%.5f",value.longitude)
        confirmed = false
        mapPosition = .region(MKCoordinateRegion(center:.init(latitude:value.latitude,longitude:value.longitude),
                                                 latitudinalMeters:300,longitudinalMeters:300))
    }
    private func applyCoordinates() {
        guard let lat = Double(latitude), let lon = Double(longitude),
              RecyclingCoordinate(latitude:lat,longitude:lon).isValid else { error = "Enter valid latitude and longitude."; return }
        setCoordinate(.init(latitude:lat,longitude:lon))
        error = nil
    }
    private func preparePhoto(_ image: UIImage, at date: Date) {
        guard modeID == game.modeSessionID, !game.isDeveloperMode else { return }
        let scale = min(1,1200 / max(image.size.width,image.size.height))
        let size = CGSize(width:image.size.width*scale,height:image.size.height*scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size:size,format:format).image { _ in image.draw(in:CGRect(origin:.zero,size:size)) }
        for quality in [0.7,0.5,0.3] {
            if let data = resized.jpegData(compressionQuality:quality), data.count <= 375_000 {
                photo = .init(data:data.base64EncodedString(),source:"camera",capturedAt:ISO8601DateFormatter().string(from:date))
                camera.stop(); error = nil; return
            }
        }
        error = "That photo is too large. Try a simpler view of the bin."
    }
    private func save() {
        do {
            guard confirmed, let modeID, let coordinate, let photo else { return }
            guard Double(latitude) == coordinate.latitude, Double(longitude) == coordinate.longitude else {
                throw VerificationError.message("Apply the edited coordinates before confirming the pin.")
            }
            try bins.save(.init(name:name,notes:notes,coordinate:coordinate,materials:Array(materials),
                                publicAccess:publicAccess,photo:photo),game:game,sessionID:modeID)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
