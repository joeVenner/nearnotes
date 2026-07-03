import Foundation
import CoreLocation
import OSLog

private let locationLogger = Logger(subsystem: "com.mosaab.NearNote", category: "Location")

@MainActor
public final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationService()
    private let manager = CLLocationManager()
    private var isActive = false
    private var lastGeofenceRefresh: Date?

    @Published public private(set) var authorizationStatus: CLAuthorizationStatus
    @Published public private(set) var currentLocation: CLLocation?

    public var monitoredReminderIds: Set<UUID> { GeofenceManager.shared.monitoredReminderIds }

    private override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .other
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    public func requestWhenInUsePermission() { manager.requestWhenInUseAuthorization() }
    public func requestAlwaysPermission() { manager.requestAlwaysAuthorization() }

    public func startInUseTracking() {
        guard !isActive else { return }
        isActive = true
        manager.startUpdatingLocation()
    }

    public func stopInUseTracking() {
        guard isActive else { return }
        isActive = false
        manager.stopUpdatingLocation()
    }

    public func requestCurrentLocation() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestLocation()
    }

    public func updateMonitoredRegions() async {
        await GeofenceManager.shared.refresh(near: currentLocation ?? manager.location)
        objectWillChange.send()
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            LocationService.shared.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
            await LocationService.shared.updateMonitoredRegions()
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let service = LocationService.shared
            service.currentLocation = location
            if service.lastGeofenceRefresh == nil || Date().timeIntervalSince(service.lastGeofenceRefresh!) > 300 {
                service.lastGeofenceRefresh = Date()
                await service.updateMonitoredRegions()
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard (error as? CLError)?.code != .locationUnknown else { return }
        locationLogger.error("Location update failed: \(error.localizedDescription, privacy: .public)")
    }
}
