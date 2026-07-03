import Foundation
import SwiftUI

public enum RadiusMode: String, CaseIterable, Identifiable {
    case automatic, meters100, meters250, meters500, meters1000, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .meters100: "100m"
        case .meters250: "250m"
        case .meters500: "500m"
        case .meters1000: "1000m"
        case .custom: "Custom"
        }
    }
    public func radius(customRadius: Double = 150) -> Double {
        switch self {
        case .automatic: 150
        case .meters100: 100
        case .meters250: 250
        case .meters500: 500
        case .meters1000: 1_000
        case .custom: customRadius
        }
    }

    public static func closest(to radius: Double) -> RadiusMode {
        let presets: [RadiusMode] = [.meters100, .meters250, .meters500, .meters1000]
        if let exact = presets.first(where: { abs($0.radius() - radius) < 1 }) { return exact }
        return .custom
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    @AppStorage("radiusMode") public var radiusModeRaw = RadiusMode.automatic.rawValue
    @AppStorage("customRadius") public var customRadius = 150.0
    @AppStorage("quietHoursEnabled") public var quietHoursEnabled = false
    @AppStorage("quietHoursStartMinutes") public var quietHoursStartMinutes = 22 * 60
    @AppStorage("quietHoursEndMinutes") public var quietHoursEndMinutes = 7 * 60
    @AppStorage("notificationCooldownMinutes") public var cooldownMinutes = 30
    @AppStorage("shareAnonymousUsage") public var shareAnonymousUsage = false
    @AppStorage("includeDiagnosticsInReports") public var includeDiagnosticsInReports = true
    @AppStorage("recentPlacesData") private var recentPlacesData = Data()
    @AppStorage("homePlaceData") private var homePlaceData = Data()
    @AppStorage("workPlaceData") private var workPlaceData = Data()

    public var recentPlaces: [Place] { decode([Place].self, from: recentPlacesData) ?? [] }
    public var homePlace: Place? {
        get { decode(Place.self, from: homePlaceData) }
        set { homePlaceData = encode(newValue); objectWillChange.send() }
    }
    public var workPlace: Place? {
        get { decode(Place.self, from: workPlaceData) }
        set { workPlaceData = encode(newValue); objectWillChange.send() }
    }

    public var radiusMode: RadiusMode {
        get { RadiusMode(rawValue: radiusModeRaw) ?? .automatic }
        set { radiusModeRaw = newValue.rawValue; objectWillChange.send() }
    }

    public func isQuiet(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard quietHoursEnabled else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if quietHoursStartMinutes <= quietHoursEndMinutes {
            return (quietHoursStartMinutes..<quietHoursEndMinutes).contains(minute)
        }
        return minute >= quietHoursStartMinutes || minute < quietHoursEndMinutes
    }

    public func remember(_ place: Place) {
        var values = recentPlaces.filter { abs($0.latitude - place.latitude) > 0.00001 || abs($0.longitude - place.longitude) > 0.00001 }
        values.insert(place, at: 0)
        recentPlacesData = encode(Array(values.prefix(6)))
        objectWillChange.send()
    }

    private func encode<T: Encodable>(_ value: T?) -> Data {
        guard let value else { return Data() }
        return (try? JSONEncoder().encode(value)) ?? Data()
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
