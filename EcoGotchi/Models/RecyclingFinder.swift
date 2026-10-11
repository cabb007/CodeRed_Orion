import Combine
import CoreLocation
import MapKit

@MainActor
// CLLocationManager is created on the main thread and delivers its delegate callbacks there.
final class RecyclingFinder: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var locations: [RecyclingLocation] = []
    @Published private(set) var area: RecyclingSearchArea?
    @Published private(set) var areaName = ""
    @Published private(set) var radius = 5_000
    @Published private(set) var activity: String?
    @Published private(set) var message: String?
    @Published private(set) var hasResults = false
    @Published private(set) var staleDate: Date?
    @Published private(set) var locationDenied = false
    @Published private(set) var mapRevision = 0

    var isBusy: Bool { activity != nil }
    private let manager = CLLocationManager()
    private let service = RecyclingLocationService()
    private var work: Task<Void, Never>?
    private var locationTimeout: Task<Void, Never>?
    private var localSearch: MKLocalSearch?
    private var wantsLocation = false
    private var requestID = UUID()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func useMyLocation() {
        cancel()
        message = nil
        wantsLocation = true
        activity = "Finding your location…"
        handleAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationDenied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        if wantsLocation { handleAuthorization() }
    }

    private func handleAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
            locationTimeout?.cancel()
            locationTimeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(18)) } catch { return }
                guard let self, self.wantsLocation else { return }
                self.finishLocationError("Couldn’t find your location. Try again or search a city or ZIP code.")
            }
        case .denied, .restricted:
            locationDenied = true
            finishLocationError("Location access is off. Search a city or ZIP code, or enable access in Settings.")
        @unknown default:
            finishLocationError("Location is unavailable. Search a city or ZIP code instead.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations values: [CLLocation]) {
        guard wantsLocation, let location = values.last(where: { $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 120 }) else { return }
        wantsLocation = false
        locationTimeout?.cancel()
        manager.stopUpdatingLocation()
        search(center: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), name: "Near you")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard wantsLocation else { return }
        finishLocationError("Couldn’t find your location. Try again or search a city or ZIP code.")
    }

    private func finishLocationError(_ text: String) {
        wantsLocation = false
        locationTimeout?.cancel()
        manager.stopUpdatingLocation()
        activity = nil
        message = text
    }

    func searchPlace(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        cancel()
        message = nil
        activity = "Finding that area…"
        let id = requestID
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address]
        let lookup = MKLocalSearch(request: request)
        localSearch = lookup
        work = Task { [weak self] in
            do {
                let response = try await lookup.start()
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.localSearch = nil
                guard let first = response.mapItems.first else {
                    self.activity = nil
                    self.message = "No matching area found. Try a city and state, or a ZIP code."
                    return
                }
                let coordinate: CLLocationCoordinate2D
                if #available(iOS 26, *) { coordinate = first.location.coordinate }
                else { coordinate = first.placemark.coordinate }
                self.search(center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude), name: first.name ?? query)
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.localSearch = nil
                self.activity = nil
                self.message = "Couldn’t find that area. Check your connection or try a city and state."
            }
        }
    }

    func setRadius(_ value: Int) {
        guard [5_000, 10_000, 25_000].contains(value), radius != value else { return }
        radius = value
        if let area { search(center: area.center, name: areaName) }
    }

    func retry() {
        guard let area else { return }
        search(center: area.center, name: areaName)
    }

    private func search(center: RecyclingCoordinate, name: String) {
        cancel()
        guard let nextArea = try? RecyclingSearchArea(center: center, radius: radius) else {
            message = RecyclingLocationError.invalidArea.localizedDescription
            return
        }
        area = nextArea
        areaName = name
        locations = []
        hasResults = false
        staleDate = nil
        message = nil
        mapRevision += 1
        activity = "Looking for recycling locations…"
        let id = requestID
        work = Task { [weak self, service] in
            do {
                let result = try await service.search(nextArea)
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.locations = result.locations
                self.staleDate = result.isStale ? result.fetchedAt : nil
                self.hasResults = true
                self.message = result.notice
                self.activity = nil
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.activity = nil
                self.message = error.localizedDescription
            }
        }
    }

    func cancel() {
        requestID = UUID()
        work?.cancel()
        work = nil
        localSearch?.cancel()
        localSearch = nil
        locationTimeout?.cancel()
        locationTimeout = nil
        wantsLocation = false
        manager.stopUpdatingLocation()
        activity = nil
    }
}
