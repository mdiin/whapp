import Foundation

/// The app's configuration: base URLs, API keys and the like, per build configuration.
///
/// The values come from the `.xcconfig` files of the app target, through the `AppConfig` dictionary in
/// its `Info.plist` (see the README). Slices declare the keys they need with
/// `Registry.requireConfig(_:testValue:)`, and read them with `string(_:)` or `url(_:)`. A required key
/// that is missing or empty stops the app at launch, with a message naming it.
///
/// Everything in `Info.plist` ships inside the app and can be read by anyone who has the app. Secrets
/// that must stay secret don't belong here.
public struct AppConfig: Sendable {
    /// The key of the dictionary in `Info.plist` that holds the values.
    public static let infoDictionaryKey = "AppConfig"

    public let values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    /// Reads the `AppConfig` dictionary of an `Info.plist`, e.g. `Bundle.main.infoDictionary`.
    /// Values that aren't strings are left out.
    public init(infoDictionary: [String: Any]) {
        let raw = infoDictionary[Self.infoDictionaryKey] as? [String: Any] ?? [:]
        self.init(values: raw.compactMapValues { $0 as? String })
    }

    /// The value of `key`. Throws `AppConfigError.missing` if it is missing or empty (an `.xcconfig`
    /// variable that isn't set becomes an empty string).
    public func string(_ key: String) throws -> String {
        guard let value = values[key], !value.isEmpty else { throw AppConfigError.missing([key]) }
        return value
    }

    /// The value of `key` as a URL. In an `.xcconfig`, write `https:/$()/example.com`: `//` starts a comment there.
    public func url(_ key: String) throws -> URL {
        let value = try string(key)
        guard let url = URL(string: value), url.scheme != nil else { throw AppConfigError.invalid(key: key, value: value) }
        return url
    }

    /// The required keys that are missing or empty.
    func missing(_ keys: some Sequence<String>) -> [String] {
        keys.filter { (values[$0] ?? "").isEmpty }.sorted()
    }

    /// This configuration, with `defaults` for the keys it lacks.
    func filling(_ defaults: [String: String]) -> AppConfig {
        var values = self.values
        for (key, value) in defaults where (values[key] ?? "").isEmpty { values[key] = value }
        return AppConfig(values: values)
    }
}

public enum AppConfigError: Error, Equatable, CustomStringConvertible {
    case missing([String])
    case invalid(key: String, value: String)

    public var description: String {
        switch self {
        case .missing(let keys):
            "Missing configuration: \(keys.joined(separator: ", ")). Set it in the app's .xcconfig files."
        case .invalid(let key, let value):
            "Invalid configuration: \(key) = \(value)"
        }
    }
}
