import CoreLocation
import Foundation
import AroundCore

/// Turns device location into a precision-7 geohash cell (~150 m).
/// Env var `AROUND_FAKE_LOCATION="lat,lon"` pins the location for tests
/// and simulator demos without touching CoreLocation.
@MainActor
final class LocationService: NSObject, ObservableObject {
    enum Status: Equatable {
        case starting
        case waitingForPermission
        case denied
        case locating
        case ready
        case pinned // fake location from environment
    }

    @Published private(set) var cellHash: String?
    @Published private(set) var status: Status = .starting

    private let manager = CLLocationManager()

    override init() {
        super.init()
        if let fake = ProcessInfo.processInfo.environment["AROUND_FAKE_LOCATION"] {
            let parts = fake.split(separator: ",").compactMap {
                Double($0.trimmingCharacters(in: .whitespaces))
            }
            if parts.count == 2 {
                cellHash = Geohash.encode(latitude: parts[0], longitude: parts[1])
                status = .pinned
                return
            }
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25
    }

    func start() {
        guard status != .pinned else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .waitingForPermission
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .denied
        default:
            if status != .ready { status = .locating }
            manager.startUpdatingLocation()
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.start() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let hash = Geohash.encode(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor in
            if self.cellHash != hash { self.cellHash = hash }
            self.status = .ready
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures are common (e.g. simulator without a location);
        // keep the last known cell and let the next update recover.
    }
}
