import Foundation
import UIKit

public enum TelemetryEventName: String {
    case appOpened = "app_opened"
    case reminderCreated = "reminder_created"
    case reminderCompleted = "reminder_completed"
    case reminderResumed = "reminder_resumed"
    case reminderArchived = "reminder_archived"
    case mapLinkResolved = "map_link_resolved"
    case mapLinkFailed = "map_link_failed"
    case feedbackSubmitted = "feedback_submitted"
}

@MainActor
public final class TelemetryService {
    public static let shared = TelemetryService()
    private let session: URLSession
    private let endpoint: URL?
    private let defaults: UserDefaults

    public var isConfigured: Bool { endpoint != nil }

    public init(
        session: URLSession = .shared,
        endpointString: String? = Bundle.main.object(forInfoDictionaryKey: "NEARNOTE_TELEMETRY_ENDPOINT") as? String,
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.endpoint = Self.configuredURL(endpointString)
        self.defaults = defaults
    }

    public func track(_ event: TelemetryEventName, properties: [String: String] = [:]) {
        guard SettingsStore.shared.shareAnonymousUsage, let endpoint else { return }
        let payload = TelemetryPayload(
            event: event.rawValue,
            installationID: installationID(),
            occurredAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            osVersion: UIDevice.current.systemVersion,
            properties: properties
        )
        Task {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(payload)
            _ = try? await session.data(for: request)
        }
    }

    private static func configuredURL(_ value: String?) -> URL? {
        guard let value, !value.isEmpty, !value.contains("$("),
              let url = URL(string: value), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private func installationID() -> String {
        if let existing = defaults.string(forKey: "anonymousInstallationID") { return existing }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: "anonymousInstallationID")
        return generated
    }
}

private struct TelemetryPayload: Codable {
    let event: String
    let installationID: String
    let occurredAt: String
    let appVersion: String
    let build: String
    let osVersion: String
    let properties: [String: String]
}

@MainActor
public struct FeedbackService {
    private let session: URLSession
    private let endpoint: URL?

    public var isConfigured: Bool { endpoint != nil }

    public init(
        session: URLSession = .shared,
        endpointString: String? = Bundle.main.object(forInfoDictionaryKey: "NEARNOTE_FEEDBACK_ENDPOINT") as? String
    ) {
        self.session = session
        if let endpointString, !endpointString.isEmpty, !endpointString.contains("$("),
           let url = URL(string: endpointString), url.scheme?.lowercased() == "https" {
            endpoint = url
        } else {
            endpoint = nil
        }
    }

    public func submit(message: String, contactEmail: String?, includeDiagnostics: Bool) async throws {
        guard let endpoint else { throw FeedbackError.notConfigured }
        let report = FeedbackPayload(
            message: message,
            contactEmail: contactEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: includeDiagnostics ? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String : nil,
            build: includeDiagnostics ? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String : nil,
            osVersion: includeDiagnostics ? UIDevice.current.systemVersion : nil,
            deviceModel: includeDiagnostics ? UIDevice.current.model : nil
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(report)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw FeedbackError.deliveryFailed
        }
    }

    public func shareText(message: String, contactEmail: String?, includeDiagnostics: Bool) -> String {
        var lines = ["NearNote problem report", "", message]
        if let contactEmail, !contactEmail.isEmpty { lines.append("\nContact: \(contactEmail)") }
        if includeDiagnostics {
            lines.append("\nApp: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"))")
            lines.append("iOS: \(UIDevice.current.systemVersion)")
            lines.append("Device: \(UIDevice.current.model)")
        }
        return lines.joined(separator: "\n")
    }
}

public enum FeedbackError: LocalizedError {
    case notConfigured, deliveryFailed
    public var errorDescription: String? {
        switch self {
        case .notConfigured: "Feedback delivery is not configured. Share the report instead."
        case .deliveryFailed: "The report could not be delivered. Try sharing it instead."
        }
    }
}

private struct FeedbackPayload: Codable {
    let message: String
    let contactEmail: String?
    let occurredAt: String
    let appVersion: String?
    let build: String?
    let osVersion: String?
    let deviceModel: String?
}
