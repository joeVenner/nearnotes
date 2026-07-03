import Foundation
import SwiftData
import CoreLocation

public enum SavedPlaceType: String, Codable {
    case home
    case work
    case recent
    case custom
}

@Model
public final class SavedPlace {
    public var id: UUID = UUID()
    public var name: String = ""
    public var address: String = ""
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var typeRaw: String = SavedPlaceType.recent.rawValue
    public var lastUsedAt: Date = Date()
    public var label: String = ""
    public var symbolName: String = "mappin.circle.fill"
    public var sortOrder: Int = 0
    
    public init(
        id: UUID = UUID(),
        name: String,
        address: String = "",
        latitude: Double,
        longitude: Double,
        type: SavedPlaceType = .recent,
        lastUsedAt: Date = Date(),
        label: String = "",
        symbolName: String = "mappin.circle.fill",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.typeRaw = type.rawValue
        self.lastUsedAt = lastUsedAt
        self.label = label
        self.symbolName = symbolName
        self.sortOrder = sortOrder
    }
    
    public var type: SavedPlaceType {
        get { SavedPlaceType(rawValue: typeRaw) ?? .recent }
        set { typeRaw = newValue.rawValue }
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Convert to a Place model for search interoperability
    public var asPlace: Place {
        Place(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            provider: .apple, // defaults
            category: nil
        )
    }

    public var displayLabel: String {
        if !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return label }
        switch type {
        case .home: return "Home"
        case .work: return "Work"
        case .recent, .custom: return name
        }
    }
}
