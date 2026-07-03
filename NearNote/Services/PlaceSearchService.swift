import Foundation
import MapKit

public protocol PlaceSearchProviding: Sendable {
    var provider: PlaceProvider { get }
    func search(query: String, near coordinate: CLLocationCoordinate2D?) async throws -> [Place]
    func nearby(category: PlaceCategory, near coordinate: CLLocationCoordinate2D) async throws -> [Place]
}

public enum PlaceSearchError: LocalizedError {
    case invalidResponse
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "The place provider returned an invalid response."
        case .unavailable: "Place search is temporarily unavailable."
        }
    }
}

public struct ApplePlaceSearchProvider: PlaceSearchProviding {
    public let provider: PlaceProvider = .apple

    public init() {}

    public func search(query: String, near coordinate: CLLocationCoordinate2D?) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coordinate {
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(12).map(place(from:))
    }

    public func nearby(category: PlaceCategory, near coordinate: CLLocationCoordinate2D) async throws -> [Place] {
        try await search(query: category.title, near: coordinate)
    }

    private func place(from item: MKMapItem) -> Place {
        let name = item.name ?? "Pinned place"
        let address = item.placemark.title ?? ""
        let detected = PlaceCategory.detect(from: [name, address, item.pointOfInterestCategory?.rawValue ?? ""])
        return Place(name: name, address: address,
                     latitude: item.placemark.coordinate.latitude,
                     longitude: item.placemark.coordinate.longitude,
                     provider: .apple, category: detected.category,
                     categoryConfidence: detected.confidence)
    }
}

public struct GooglePlaceSearchProvider: PlaceSearchProviding {
    public let provider: PlaceProvider = .google
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func search(query: String, near coordinate: CLLocationCoordinate2D?) async throws -> [Place] {
        var body: [String: Any] = ["textQuery": query, "pageSize": 10]
        if let coordinate {
            body["locationBias"] = ["circle": ["center": ["latitude": coordinate.latitude,
                                                              "longitude": coordinate.longitude],
                                                   "radius": 20_000.0]]
        }
        return try await request(endpoint: "places:searchText", body: body)
    }

    public func nearby(category: PlaceCategory, near coordinate: CLLocationCoordinate2D) async throws -> [Place] {
        try await request(endpoint: "places:searchNearby", body: [
            "includedTypes": [googleType(for: category)],
            "maxResultCount": 10,
            "locationRestriction": ["circle": ["center": ["latitude": coordinate.latitude,
                                                               "longitude": coordinate.longitude],
                                                     "radius": 1_500.0]]
        ])
    }

    private func request(endpoint: String, body: [String: Any]) async throws -> [Place] {
        guard let url = URL(string: "https://places.googleapis.com/v1/\(endpoint)") else { throw PlaceSearchError.unavailable }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location,places.types,places.primaryType", forHTTPHeaderField: "X-Goog-FieldMask")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw PlaceSearchError.invalidResponse }
        let decoded = try JSONDecoder().decode(GoogleResponse.self, from: data)
        return decoded.places.map { value in
            let detected = PlaceCategory.detect(from: value.types + [value.primaryType ?? "", value.displayName?.text ?? ""])
            return Place(name: value.displayName?.text ?? "Place", address: value.formattedAddress ?? "",
                         latitude: value.location.latitude, longitude: value.location.longitude,
                         provider: .google, providerPlaceID: value.id,
                         category: detected.category, categoryConfidence: detected.confidence)
        }
    }

    private func googleType(for category: PlaceCategory) -> String {
        switch category {
        case .gasStation: "gas_station"
        case .hardwareStore: "hardware_store"
        case .postOffice: "post_office"
        case .mall: "shopping_mall"
        default: category.rawValue
        }
    }
}

private struct GoogleResponse: Decodable {
    struct GooglePlace: Decodable {
        struct DisplayName: Decodable { let text: String }
        struct Location: Decodable { let latitude: Double; let longitude: Double }
        let id: String?
        let displayName: DisplayName?
        let formattedAddress: String?
        let location: Location
        let types: [String]
        let primaryType: String?
    }
    let places: [GooglePlace]
}

@MainActor
public final class PlaceSearchService: ObservableObject {
    @Published public private(set) var results: [Place] = []
    @Published public private(set) var isSearching = false
    @Published public private(set) var providerInUse: PlaceProvider = .apple
    @Published public private(set) var errorMessage: String?

    private let apple: any PlaceSearchProviding
    private let google: (any PlaceSearchProviding)?
    private var task: Task<Void, Never>?

    public init(apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String,
                apple: any PlaceSearchProviding = ApplePlaceSearchProvider()) {
        self.apple = apple
        if let apiKey, !apiKey.isEmpty, apiKey != "$(GOOGLE_PLACES_API_KEY)" {
            self.google = GooglePlaceSearchProvider(apiKey: apiKey)
        } else {
            self.google = nil
        }
    }

    public var hasGoogleProvider: Bool { google != nil }

    public func search(query: String, near coordinate: CLLocationCoordinate2D? = nil) {
        task?.cancel()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { results = []; errorMessage = nil; return }
        task = Task {
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            isSearching = true
            errorMessage = nil
            defer { isSearching = false }
            if let google {
                do {
                    results = try await google.search(query: query, near: coordinate)
                    providerInUse = .google
                    return
                } catch { /* Apple fallback is intentional. */ }
            }
            do {
                results = try await apple.search(query: query, near: coordinate)
                providerInUse = .apple
            } catch {
                results = []
                errorMessage = error.localizedDescription
            }
        }
    }

    public func nearby(category: PlaceCategory, near coordinate: CLLocationCoordinate2D) async -> [Place] {
        if let google, let places = try? await google.nearby(category: category, near: coordinate), !places.isEmpty {
            return places
        }
        return (try? await apple.nearby(category: category, near: coordinate)) ?? []
    }
}
