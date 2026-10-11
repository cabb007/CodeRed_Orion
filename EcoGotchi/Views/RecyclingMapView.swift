import SwiftUI
import MapKit

struct RecyclingMapView: View {
    @ObservedObject var finder: RecyclingFinder
    @StateObject private var bins = CommunityBinStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var searchText = ""
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find a bin").font(.title2.bold())
                    Text("A little care, closer to home").font(.caption)
                }
                Spacer(minLength: 8)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                        .background(Palette.sage, in: PixelFrame())
                }.buttonStyle(.plain).accessibilityLabel("Close recycling map")
            }.padding(20)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        searchControls
                        if let activity = finder.activity {
                            HStack(spacing: 10) { ProgressView(); Text(activity).font(.caption) }
                                .accessibilityElement(children: .combine)
                        }
                        if let message = finder.message {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(message).font(.subheadline)
                                if finder.area != nil {
                                    Button("Try again") { finder.retry() }.buttonStyle(.bordered).disabled(finder.isBusy)
                                }
                                if finder.locationDenied {
                                    Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                                        .buttonStyle(.bordered)
                                }
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).pixelPanel(Palette.paper, shadow: false)
                        }
                        if let area = finder.area {
                            map(area)
                            results
                        } else if !finder.isBusy {
                            VStack(spacing: 12) {
                                Image(systemName: "map.fill").font(.system(size: 40)).foregroundStyle(Palette.forest)
                                Text("Find your next recycling stop").font(.headline)
                                Text("Look for mapped bins and drop-off centers. Choose your location or search an area to get started.")
                                    .font(.subheadline).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).padding(.vertical, 22)
                        }
                        CommunityLandmarksView(bins:bins,area:finder.area)
                        attribution
                    }.padding(.horizontal, 20).padding(.bottom, 24)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: selectedID) { _, value in
                        if value != nil { proxy.scrollTo("location-details", anchor: .top) }
                    }
            }
        }
        .background(Palette.cream).foregroundStyle(Palette.forest)
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .onAppear {
            recenter()
            if finder.area != nil && !finder.hasResults && finder.message == nil { finder.retry() }
        }
        .onChange(of: finder.mapRevision) { _, _ in selectedID = nil; recenter() }
        .onDisappear { finder.cancel() }
    }

    private var searchControls: some View {
        VStack(spacing: 12) {
            Button {
                searchFocused = false
                finder.useMyLocation()
            } label: {
                Label("Use my location", systemImage: "location.fill").frame(maxWidth: .infinity)
            }.buttonStyle(PixelButtonStyle()).disabled(finder.isBusy)
            HStack(spacing: 8) {
                TextField("City or ZIP code", text: $searchText)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .submitLabel(.search).focused($searchFocused).onSubmit(searchPlace)
                    .padding(12).background(Palette.paper, in: PixelFrame())
                    .accessibilityLabel("Search city or ZIP code")
                Button(action: searchPlace) {
                    Image(systemName: "magnifyingglass").font(.headline).frame(width: 44, height: 44)
                        .background(Palette.sage, in: PixelFrame())
                }.buttonStyle(.plain).accessibilityLabel("Search this area")
                    .disabled(finder.isBusy || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if finder.area != nil {
                Picker("Search radius", selection: Binding(get: { finder.radius }, set: finder.setRadius)) {
                    Text("5 km").tag(5_000)
                    Text("10 km").tag(10_000)
                    Text("25 km").tag(25_000)
                }.pickerStyle(.segmented).disabled(finder.isBusy)
            }
        }
    }

    private func map(_ area: RecyclingSearchArea) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(finder.areaName).font(.headline)
            Map(position: $position, selection: $selectedID) {
                Annotation("Search area", coordinate: coordinate(area.center)) {
                    Image(systemName: "scope").font(.title2).foregroundStyle(.blue)
                        .padding(5).background(.white, in: Circle()).accessibilityLabel("Center of searched area")
                }
                ForEach(bins.saved.filter { entry in
                    (entry.shared == nil || entry.server != VerificationConnection.savedURL) &&
                        area.center.distance(to:entry.draft.coordinate) <= Double(area.radius)
                }) { entry in
                    Marker(entry.draft.name,coordinate:coordinate(entry.draft.coordinate)).tint(.blue)
                }
                ForEach(bins.nearby(area,origin:VerificationConnection.savedURL)) { bin in
                    Marker(bin.name,coordinate:coordinate(bin.coordinate)).tint(.purple)
                }
                ForEach(finder.locations) { location in
                    Marker(location.name, systemImage: "arrow.3.trianglepath", coordinate: coordinate(location.coordinate))
                        .tint(location.id == selectedID ? Palette.coral : Palette.forest).tag(location.id)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            .frame(height: 250).clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Text("Distances from the search point").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Recenter", action: recenter).font(.caption).frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder private var results: some View {
        if let saved = finder.staleDate {
            Text("Couldn’t refresh. Showing saved locations from \(saved.formatted(date: .abbreviated, time: .shortened)).")
                .font(.caption).padding(12).pixelPanel(Palette.gold.opacity(0.45), shadow: false)
        }
        if let selected = finder.locations.first(where: { $0.id == selectedID }) {
            detail(selected).id("location-details")
        }
        if finder.hasResults {
            if finder.locations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No mapped recycling spots here yet").font(.headline)
                    Text("Try a wider radius or another area. Some bins haven’t been added to the map.").font(.subheadline)
                    if finder.radius < 25_000 {
                        Button("Search farther") { finder.setRadius(finder.radius == 5_000 ? 10_000 : 25_000) }
                            .buttonStyle(.bordered)
                    }
                }.padding(14).pixelPanel(Palette.paper, shadow: false)
            } else {
                Text("\(finder.locations.count) nearby location\(finder.locations.count == 1 ? "" : "s")")
                    .font(.headline)
                LazyVStack(spacing: 10) {
                    ForEach(finder.locations) { location in
                        Button {
                            selectedID = location.id
                            position = .region(MKCoordinateRegion(center: coordinate(location.coordinate), latitudinalMeters: 1_500, longitudinalMeters: 1_500))
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "arrow.3.trianglepath").font(.title3).padding(.top, 3)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(location.name).font(.subheadline.bold()).multilineTextAlignment(.leading)
                                    Text("\(location.kind) · \(distance(location))").font(.caption)
                                    Text(location.materials.isEmpty ? "Materials not listed" : location.materials.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: selectedID == location.id ? "checkmark.circle.fill" : "chevron.right")
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .pixelPanel(selectedID == location.id ? Palette.sage : Palette.paper, shadow: false)
                        }.buttonStyle(.plain).accessibilityHint("Show materials and directions")
                    }
                }
            }
        }
    }

    private func detail(_ location: RecyclingLocation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(location.name).font(.headline)
            Text("\(location.kind) · \(distance(location))").font(.caption)
            Text("Listed by \(location.sourceName)").font(.caption).foregroundStyle(.secondary)
            if let address = location.address { Text(address).font(.subheadline) }
            Text(location.materials.isEmpty ? "Accepted materials haven’t been listed. Check the signs at this location." : "Listed materials: \(location.materials.joined(separator: ", ")).")
                .font(.subheadline)
            if let hours = location.hours { Text("Listed hours: \(hours == "24/7" ? "24 hours, every day" : hours)").font(.caption) }
            Text(location.publicAccessListed ? "Public access listed · confirm signs on arrival" : "Access not listed · check before visiting")
                .font(.caption)
            if location.hasFee { Text("Fees may apply").font(.caption) }
            Button { directions(to: location) } label: {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity)
            }.buttonStyle(PixelButtonStyle())
            Link("View source details", destination: location.sourceURL).font(.caption).frame(minHeight: 44)
        }.padding(16).pixelPanel(Palette.paper, shadow: false)
    }

    private var attribution: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Community-mapped locations may be incomplete. Check bin signs for accepted materials and access.").font(.caption)
            Text("Search uses your approximate area with OpenStreetMap’s Overpass service. City searches use Apple Maps.")
                .font(.caption2).foregroundStyle(.secondary)
            Link("Recycling data © OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                .font(.caption2).frame(minHeight: 44)
            if finder.locations.contains(where: { $0.sourceName == "City of Houston" }) {
                Link("Additional drop-off data: City of Houston", destination: URL(string: "https://www.houstontx.gov/solidwaste/recycling_map.html")!)
                    .font(.caption2).frame(minHeight: 44)
            }
        }
    }

    private func searchPlace() {
        guard !finder.isBusy else { return }
        searchFocused = false
        finder.searchPlace(searchText)
    }

    private func recenter() {
        guard let area = finder.area else { return }
        position = .region(MKCoordinateRegion(center: coordinate(area.center), latitudinalMeters: Double(area.radius) * 2.3,
                                             longitudinalMeters: Double(area.radius) * 2.3))
    }

    private func coordinate(_ value: RecyclingCoordinate) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: value.latitude, longitude: value.longitude)
    }

    private func distance(_ location: RecyclingLocation) -> String {
        guard let center = finder.area?.center else { return "" }
        let meters = center.distance(to: location.coordinate)
        return meters < 1_000 ? "about \(max(10, Int((meters / 10).rounded()) * 10)) m" : String(format: "about %.1f km", meters / 1_000)
    }

    private func directions(to location: RecyclingLocation) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate(location.coordinate)))
        item.name = location.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}
