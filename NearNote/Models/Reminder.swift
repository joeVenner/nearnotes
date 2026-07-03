import Foundation
import SwiftData
import CoreLocation

@Model
public final class Reminder {
    public var id: UUID = UUID()
    public var title: String = ""
    public var notes: String = ""
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var placeName: String = ""
    public var placeAddress: String = ""
    public var placeProvider: String = PlaceProvider.apple.rawValue
    public var providerPlaceID: String?
    public var placeCategory: String?
    public var categoryConfidence: Double = 0
    public var triggerModeRaw: String = ReminderTriggerMode.specificPlace.rawValue
    public var alternativesDisabled: Bool = false
    public var radius: Double = 100.0 // meters
    public var triggerOnArrival: Bool = true // true = arrival, false = departure
    public var isOneTime: Bool = true
    public var isEnabled: Bool = true
    public var isCompleted: Bool = false
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    // Phase 1 Additions
    public var colorHex: String = "#007AFF"
    public var startTime: Date? = nil
    public var endTime: Date? = nil
    public var lastTriggeredAt: Date?
    public var snoozedUntil: Date?
    
    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        latitude: Double,
        longitude: Double,
        placeName: String = "",
        placeAddress: String = "",
        placeProvider: PlaceProvider = .apple,
        providerPlaceID: String? = nil,
        placeCategory: PlaceCategory? = nil,
        categoryConfidence: Double = 0,
        triggerMode: ReminderTriggerMode = .specificPlace,
        radius: Double = 100.0,
        triggerOnArrival: Bool = true,
        isOneTime: Bool = true,
        isEnabled: Bool = true,
        isCompleted: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.placeAddress = placeAddress
        self.placeProvider = placeProvider.rawValue
        self.providerPlaceID = providerPlaceID
        self.placeCategory = placeCategory?.rawValue
        self.categoryConfidence = categoryConfidence
        self.triggerModeRaw = triggerMode.rawValue
        self.radius = radius
        self.triggerOnArrival = triggerOnArrival
        self.isOneTime = isOneTime
        self.isEnabled = isEnabled
        self.isCompleted = isCompleted
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.lastTriggeredAt = lastTriggeredAt
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var triggerMode: ReminderTriggerMode {
        get { ReminderTriggerMode(rawValue: triggerModeRaw) ?? .specificPlace }
        set { triggerModeRaw = newValue.rawValue }
    }

    public var category: PlaceCategory? {
        get { placeCategory.flatMap(PlaceCategory.init(rawValue:)) }
        set { placeCategory = newValue?.rawValue }
    }
    
    public var regionIdentifier: String {
        id.uuidString
    }

    public func markDone() {
        isCompleted = true
        isEnabled = false
        isArchived = false
    }

    public func resume() {
        isCompleted = false
        isArchived = false
        isEnabled = true
        snoozedUntil = nil
        lastTriggeredAt = nil
    }

    public func archive() {
        isArchived = true
        isEnabled = false
    }

    public func restoreFromArchive() {
        isArchived = false
        if !isCompleted { isEnabled = true }
    }
    
    public var clRegion: CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: regionIdentifier
        )
        region.notifyOnEntry = triggerOnArrival
        region.notifyOnExit = !triggerOnArrival
        return region
    }
}
