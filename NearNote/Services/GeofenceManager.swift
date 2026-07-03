import Foundation
import CoreLocation
import OSLog

private let geofenceLogger = Logger(subsystem: "com.mosaab.NearNote", category: "Geofence")

@MainActor
public final class GeofenceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = GeofenceManager()
    private let manager = CLLocationManager()
    private let placeSearch = PlaceSearchService()
    @Published public private(set) var monitoredReminderIds: Set<UUID> = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .other
    }

    public func refresh(near location: CLLocation?) async {
        let active = ReminderStore.shared.fetchActive()
        let sorted = active.sorted { lhs, rhs in
            guard let location else { return lhs.createdAt > rhs.createdAt }
            return location.distance(from: CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)) <
                   location.distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
        }
        var regions: [(region: CLCircularRegion, reminderID: UUID)] = sorted.prefix(20).map { ($0.clRegion, $0.id) }

        if let location {
            for reminder in sorted where reminder.triggerMode == .similarCategory && !reminder.alternativesDisabled {
                guard regions.count < 20, let category = reminder.category else { break }
                let alternatives = await placeSearch.nearby(category: category, near: location.coordinate)
                for place in alternatives.prefix(3) where regions.count < 20 {
                    let original = CLLocation(latitude: reminder.latitude, longitude: reminder.longitude)
                    let candidate = CLLocation(latitude: place.latitude, longitude: place.longitude)
                    guard original.distance(from: candidate) > max(reminder.radius * 1.5, 200) else { continue }
                    let identifier = alternativeIdentifier(reminderID: reminder.id, place: place)
                    let region = CLCircularRegion(center: place.coordinate, radius: reminder.radius, identifier: identifier)
                    region.notifyOnEntry = reminder.triggerOnArrival
                    region.notifyOnExit = !reminder.triggerOnArrival
                    regions.append((region, reminder.id))
                }
            }
        }
        apply(regions)
    }

    public func stop(reminder: Reminder) {
        for region in manager.monitoredRegions where region.identifier == reminder.regionIdentifier || region.identifier.hasPrefix("alt|\(reminder.id.uuidString)|") {
            manager.stopMonitoring(for: region)
        }
        monitoredReminderIds.remove(reminder.id)
    }

    private func apply(_ targets: [(region: CLCircularRegion, reminderID: UUID)]) {
        let identifiers = Set(targets.map(\.region.identifier))
        for region in manager.monitoredRegions where !identifiers.contains(region.identifier) { manager.stopMonitoring(for: region) }
        let existing = Set(manager.monitoredRegions.map(\.identifier))
        for target in targets where !existing.contains(target.region.identifier) { manager.startMonitoring(for: target.region) }
        monitoredReminderIds = Set(targets.map(\.reminderID))
    }

    private func alternativeIdentifier(reminderID: UUID, place: Place) -> String {
        let safeName = String(place.name.replacingOccurrences(of: "|", with: " ").prefix(40))
        return "alt|\(reminderID.uuidString)|\(place.latitude)|\(place.longitude)|\(safeName)"
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in GeofenceManager.shared.handle(region: region) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in GeofenceManager.shared.handle(region: region) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        geofenceLogger.error("Region monitoring failed: \(error.localizedDescription, privacy: .public)")
    }

    private func handle(region: CLRegion) {
        let parsed = parse(region.identifier)
        guard let reminder = ReminderStore.shared.fetchReminder(withId: parsed.id), reminder.isEnabled, !reminder.isCompleted, !reminder.isArchived else { return }
        let settings = SettingsStore.shared
        if let snoozedUntil = reminder.snoozedUntil, snoozedUntil > Date() { return }
        if let last = reminder.lastTriggeredAt, Date().timeIntervalSince(last) < Double(settings.cooldownMinutes * 60) { return }
        
        // Enforce time constraints
        if let start = reminder.startTime, let end = reminder.endTime {
            let calendar = Calendar.current
            let now = Date()
            
            // Extract only the hour and minute from start/end times
            let startComponents = calendar.dateComponents([.hour, .minute], from: start)
            let endComponents = calendar.dateComponents([.hour, .minute], from: end)
            
            let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
            let startMinute = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
            let endMinute = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
            let nowMinute = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
            let inWindow = startMinute <= endMinute
                ? (startMinute...endMinute).contains(nowMinute)
                : nowMinute >= startMinute || nowMinute <= endMinute

            if !inWindow {
                geofenceLogger.info("Reminder triggered outside of allowed time window. Suppressing.")
                return
            }
        }
        
        reminder.lastTriggeredAt = Date()
        ReminderStore.shared.save()
        NotificationService.shared.triggerNotification(for: reminder, alternativePlaceName: parsed.placeName,
                                                       alternativeCoordinate: parsed.coordinate)
    }

    private func parse(_ identifier: String) -> (id: UUID, placeName: String?, coordinate: CLLocationCoordinate2D?) {
        let parts = identifier.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if parts.count >= 5, parts[0] == "alt", let id = UUID(uuidString: parts[1]),
           let lat = Double(parts[2]), let lon = Double(parts[3]) {
            return (id, parts[4], CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return (UUID(uuidString: identifier) ?? UUID(), nil, nil)
    }
}
