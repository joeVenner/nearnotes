import Foundation
import CoreLocation

public enum LinkResolverError: LocalizedError {
    case invalidURL
    case unableToResolve
    case unsupportedProvider
    case timedOut
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "That doesn't look like a valid link."
        case .unableToResolve: return "We couldn't figure out exactly where this link points."
        case .unsupportedProvider: return "We don't support links from that app yet. Try Google Maps, Apple Maps, or Waze."
        case .timedOut: return "Google Maps took too long to expand this link. Check your connection and try again."
        }
    }
}

public struct ResolvedLink: Sendable {
    public let coordinate: CLLocationCoordinate2D
    public let provider: PlaceProvider
    public let originalURL: URL
    
    public var place: Place {
        Place(
            name: "Pasted Link",
            address: originalURL.absoluteString,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            provider: provider,
            category: nil
        )
    }
}

@MainActor
public final class LinkResolverService: ObservableObject {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func resolve(url: URL) async throws -> ResolvedLink {
        let host = url.host?.lowercased() ?? ""
        
        // Handle direct parseable links
        if host.contains("waze.com") {
            return try parseWaze(url: url)
        } else if host.contains("maps.apple.com") || host.contains("apple.com") && url.path.contains("/maps") {
            return try parseAppleMaps(url: url)
        }
        
        // Handle Google Maps (which might be a short link)
        if host.contains("google.com") || host.contains("goo.gl") {
            // It might be a short link (maps.app.goo.gl, goo.gl). Let's expand it.
            let expanded = try await expandShortURL(url)
            if let result = try? parseGoogleMaps(url: expanded.url) { return result }
            if let html = String(data: expanded.body, encoding: .utf8),
               let coordinate = Self.googleCoordinate(in: html) {
                return ResolvedLink(coordinate: coordinate, provider: .google, originalURL: expanded.url)
            }
            throw LinkResolverError.unableToResolve
        }
        
        throw LinkResolverError.unsupportedProvider
    }

    public func resolvePlace(url: URL) async throws -> Place {
        let resolved = try await resolve(url: url)
        let location = CLLocation(latitude: resolved.coordinate.latitude, longitude: resolved.coordinate.longitude)
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        let detected = PlaceCategory.detect(from: [
            placemark?.name ?? "",
            placemark?.areasOfInterest?.joined(separator: " ") ?? ""
        ])
        let queryName = URLComponents(url: resolved.originalURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { ["q", "query"].contains($0.name) })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Place(
            name: queryName.flatMap { $0.isEmpty ? nil : $0 }
                ?? placemark?.areasOfInterest?.first
                ?? placemark?.name
                ?? "Dropped Pin",
            address: [placemark?.thoroughfare, placemark?.locality, placemark?.country]
                .compactMap { $0 }
                .joined(separator: ", "),
            latitude: resolved.coordinate.latitude,
            longitude: resolved.coordinate.longitude,
            provider: resolved.provider,
            category: detected.category,
            categoryConfidence: detected.confidence
        )
    }
    
    private func expandShortURL(_ url: URL) async throws -> (url: URL, body: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("NearNote/1.0 iOS", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...399).contains(httpResponse.statusCode),
                  let finalURL = httpResponse.url else { throw LinkResolverError.unableToResolve }
            return (finalURL, data)
        } catch let error as URLError where error.code == .timedOut {
            throw LinkResolverError.timedOut
        } catch let error as LinkResolverError {
            throw error
        } catch {
            throw LinkResolverError.unableToResolve
        }
    }
    
    private func parseGoogleMaps(url: URL) throws -> ResolvedLink {
        if let coordinate = Self.googleCoordinate(in: url.absoluteString.removingPercentEncoding ?? url.absoluteString) {
            return ResolvedLink(coordinate: coordinate, provider: .google, originalURL: url)
        }
        
        // Look for ?q=lat,lng or &q=lat,lng
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let q = components.queryItems?.first(where: { ["q", "query", "destination", "ll"].contains($0.name) })?.value {
            let parts = q.split(separator: ",")
            if parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) {
                return ResolvedLink(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), provider: .google, originalURL: url)
            }
        }
        
        throw LinkResolverError.unableToResolve
    }

    static func googleCoordinate(in text: String) -> CLLocationCoordinate2D? {
        let patterns = [
            #"@(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)"#,
            #"!3d(-?\d{1,2}(?:\.\d+)?)[^0-9-]+!4d(-?\d{1,3}(?:\.\d+)?)"#,
            #"(?:center|destination|query|q|ll)=(-?\d{1,2}(?:\.\d+)?)(?:%2C|,)(-?\d{1,3}(?:\.\d+)?)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  match.numberOfRanges >= 3,
                  let latRange = Range(match.range(at: 1), in: text),
                  let lonRange = Range(match.range(at: 2), in: text),
                  let latitude = Double(text[latRange]),
                  let longitude = Double(text[lonRange]),
                  (-90...90).contains(latitude), (-180...180).contains(longitude) else { continue }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return nil
    }
    
    private func parseAppleMaps(url: URL) throws -> ResolvedLink {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let ll = components.queryItems?.first(where: { $0.name == "ll" })?.value {
                let parts = ll.split(separator: ",")
                if parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) {
                    return ResolvedLink(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), provider: .apple, originalURL: url)
                }
            }
            if let q = components.queryItems?.first(where: { $0.name == "q" })?.value {
                let parts = q.split(separator: ",")
                if parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) {
                    return ResolvedLink(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), provider: .apple, originalURL: url)
                }
            }
        }
        throw LinkResolverError.unableToResolve
    }
    
    private func parseWaze(url: URL) throws -> ResolvedLink {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let ll = components.queryItems?.first(where: { $0.name == "ll" })?.value {
            let parts = ll.split(separator: ",")
            if parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) {
                return ResolvedLink(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), provider: .link, originalURL: url)
            }
        }
        throw LinkResolverError.unableToResolve
    }
    
    public static func extractURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url }.first
    }
}
