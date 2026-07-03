import Foundation

enum AppConfiguration {
    static var privacyPolicyURL: URL? { configuredURL(for: "NEARNOTE_PRIVACY_URL") }
    static var supportURL: URL? { configuredURL(for: "NEARNOTE_SUPPORT_URL") }

    private static func configuredURL(for key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("$("),
              let url = URL(string: value),
              url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
