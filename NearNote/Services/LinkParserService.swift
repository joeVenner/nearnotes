import Foundation

public enum LinkParseResult: Equatable {
    case place(Place)
    case needsExpandedLink
    case unsupported
}

public struct LinkParserService {
    public init() {}

    public func parse(_ rawValue: String) -> LinkParseResult {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), let host = url.host?.lowercased() else { return .unsupported }
        let supported = host.contains("google.") || host.contains("goo.gl") || host.contains("apple.com") || host.contains("waze.com")
        guard supported else { return .unsupported }
        if host == "maps.app.goo.gl" || host == "goo.gl" || host == "waze.to" { return .needsExpandedLink }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = (components?.queryItems ?? []).reduce(into: [String: String]()) { values, item in
            values[item.name.lowercased()] = item.value ?? ""
        }
        let name = items["q"]?.removingPercentEncoding ?? items["query"]?.removingPercentEncoding ?? "Shared place"

        if let pair = coordinatePair(in: items["ll"] ?? items["query"] ?? items["center"] ?? "") {
            return .place(Place(name: cleanName(name), latitude: pair.0, longitude: pair.1, provider: .link))
        }
        if let pair = coordinatePair(in: url.absoluteString, pattern: #"@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)"#) {
            return .place(Place(name: cleanName(name), latitude: pair.0, longitude: pair.1, provider: .link))
        }
        return .unsupported
    }

    private func coordinatePair(in value: String, pattern: String = #"(-?\d+(?:\.\d+)?)[,~](-?\d+(?:\.\d+)?)"#) -> (Double, Double)? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let latRange = Range(match.range(at: 1), in: value),
              let lonRange = Range(match.range(at: 2), in: value),
              let lat = Double(value[latRange]), let lon = Double(value[lonRange]),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return (lat, lon)
    }

    private func cleanName(_ value: String) -> String {
        let candidate = value.replacingOccurrences(of: "+", with: " ")
        return coordinatePair(in: candidate) == nil && !candidate.isEmpty ? candidate : "Shared place"
    }
}
