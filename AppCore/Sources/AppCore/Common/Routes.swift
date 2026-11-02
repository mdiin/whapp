import Foundation
import Observation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// A screen and its parameters: what is pushed on the navigation stack.
///
/// `name` is the screen's slice, `{context}/{slice}`. Slices refer to each other's screens only by name,
/// so a link to a screen whose slice isn't built yet compiles, and shows disabled.
public struct Route: Hashable, Sendable, Identifiable {
    public let name: String
    public let parameters: [String: FieldValue]

    public init(_ name: String, _ parameters: [String: FieldValue] = [:]) {
        self.name = name
        self.parameters = parameters
    }

    public var id: Route { self }

    /// Decodes the parameters into the screen's own `Decodable` type, as a command decodes its payload.
    public func decode<T: Decodable>(_ type: T.Type = T.self) throws -> T {
        try PayloadDecoder.decode(T.self, from: parameters)
    }
}

/// A screen's entry in the route registry.
public struct RouteEntry: Sendable {
    public let name: String
    public let title: String
    /// The names of the parameters the screen needs. A screen without any can be opened from the
    /// "Screens" catalog.
    public let parameters: [String]

    #if canImport(SwiftUI)
    let screen: @MainActor @Sendable (Route, AppSystem) throws -> AnyView
    #endif
}

/// The screens slices have registered, by name.
public struct RouteRegistry: Sendable {
    let entries: [String: RouteEntry]

    public func isRegistered(_ name: String) -> Bool { entries[name] != nil }

    public func entry(_ name: String) -> RouteEntry? { entries[name] }

    /// Every entry, by title.
    public var all: [RouteEntry] {
        entries.values.sorted { ($0.title, $0.name) < ($1.title, $1.name) }
    }
}

/// The navigation state of one window: the stack of screens, and a sheet.
@MainActor
@Observable
public final class Navigator {
    public var path: [Route]
    public var sheet: Route?

    public init(path: [Route] = [], sheet: Route? = nil) {
        self.path = path
        self.sheet = sheet
    }

    /// Goes to `route`: closes a sheet first, then goes back to `route` if it is already on the
    /// stack, and pushes it otherwise. This is how a screen moves on after a command succeeded.
    public func navigate(to route: Route) {
        sheet = nil
        if let index = path.lastIndex(of: route) {
            path.removeSubrange((index + 1)...)
        } else {
            path.append(route)
        }
    }

    /// Shows `route` as a sheet.
    public func present(_ route: Route) {
        sheet = route
    }

    public func dismissSheet() {
        sheet = nil
    }

    public func popToRoot() {
        sheet = nil
        path.removeAll()
    }
}
