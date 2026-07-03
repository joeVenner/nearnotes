import Foundation
import CoreLocation

public enum PlaceProvider: String, Codable, CaseIterable, Sendable {
    case apple
    case google
    case link
    case manual
}

public enum ReminderTriggerMode: String, Codable, CaseIterable, Sendable {
    case specificPlace
    case similarCategory

    public var title: String {
        switch self {
        case .specificPlace: "Only this place"
        case .similarCategory: "Any nearby similar place"
        }
    }
}

public enum PlaceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case pharmacy, supermarket, gasStation, atm, florist, gym, cafe, restaurant
    case mall, hospital, office, bakery, hardwareStore, postOffice, bank, parking

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .gasStation: "Gas station"
        case .hardwareStore: "Hardware store"
        case .postOffice: "Post office"
        default: rawValue.capitalized
        }
    }

    public var symbol: String {
        switch self {
        case .pharmacy: "cross.case.fill"
        case .supermarket: "cart.fill"
        case .gasStation: "fuelpump.fill"
        case .atm, .bank: "banknote.fill"
        case .florist: "leaf.fill"
        case .gym: "dumbbell.fill"
        case .cafe: "cup.and.saucer.fill"
        case .restaurant, .bakery: "fork.knife"
        case .mall: "bag.fill"
        case .hospital: "cross.fill"
        case .office: "building.2.fill"
        case .hardwareStore: "wrench.and.screwdriver.fill"
        case .postOffice: "envelope.fill"
        case .parking: "parkingsign.circle.fill"
        }
    }

    public static func detect(from values: [String]) -> (category: PlaceCategory?, confidence: Double) {
        let text = values.joined(separator: " ").lowercased()
        let mappings: [(PlaceCategory, [String])] = [
            (.pharmacy, ["pharmacy", "drugstore", "chemist"]),
            (.supermarket, ["supermarket", "grocery", "food_store"]),
            (.gasStation, ["gas_station", "petrol", "fuel"]),
            (.atm, ["atm"]), (.florist, ["florist", "flower"]),
            (.gym, ["gym", "fitness"]), (.cafe, ["cafe", "coffee"]),
            (.restaurant, ["restaurant", "meal_takeaway"]), (.mall, ["shopping_mall", "mall"]),
            (.hospital, ["hospital", "medical_center"]), (.office, ["office", "corporate"]),
            (.bakery, ["bakery"]), (.hardwareStore, ["hardware_store"]),
            (.postOffice, ["post_office"]), (.bank, ["bank"]), (.parking, ["parking"])
        ]
        for (category, tokens) in mappings where tokens.contains(where: text.contains) {
            return (category, values.count > 1 ? 0.95 : 0.82)
        }
        return (nil, 0)
    }
}

public struct Place: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var address: String
    public var latitude: Double
    public var longitude: Double
    public var provider: PlaceProvider
    public var providerPlaceID: String?
    public var category: PlaceCategory?
    public var categoryConfidence: Double

    public init(id: UUID = UUID(), name: String, address: String = "", latitude: Double,
                longitude: Double, provider: PlaceProvider, providerPlaceID: String? = nil,
                category: PlaceCategory? = nil, categoryConfidence: Double = 0) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.provider = provider
        self.providerPlaceID = providerPlaceID
        self.category = category
        self.categoryConfidence = categoryConfidence
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
