import Foundation
import GRDB
import Ledjer
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Something with a lifecycle: an automation or a persisted view. `Lifecycle` starts it when the app
/// becomes active and stops it when the app goes to the background.
public struct Component: Sendable {
    public let name: String
    let start: @Sendable (AppSystem) async throws -> RunningComponent
}

/// A started component.
public struct RunningComponent: Sendable {
    let stop: @Sendable () async -> Void

    public init(stop: @escaping @Sendable () async -> Void) { self.stop = stop }
}

/// What the slices register: built once, in `Slices.register(in:)`, before the `AppSystem` exists.
///
/// Each slice has a `register(in:)` function in its own file, and `Slices.register(in:)` calls it.
/// Names are `{context}/{slice}` and must be unique per kind; a duplicate makes creating the
/// `AppSystem` throw.
public struct Registry {
    var commands: [String: CommandRegistry.Handler] = [:]
    var routes: [String: RouteEntry] = [:]
    var components: [Component] = []
    var migrations: [Migration] = []
    var configTestValues: [String: String] = [:]
    var usedCommands: [String: Set<String>] = [:]
    var usedRoutes: [String: Set<String>] = [:]
    var problems: [String] = []

    public init() {}

    /// Registers a command: a `Decodable` command type and its handler. The payload a screen sends is
    /// decoded into `C`; a payload that doesn't fit becomes a `CommandInputError` for the form.
    public mutating func command<C: Decodable & Sendable>(
        _ name: String,
        _ type: C.Type,
        handle: @escaping @Sendable (C, AppSystem) async throws -> Void
    ) {
        guard commands[name] == nil else { return problems.append("Command \(name) is registered twice") }
        commands[name] = CommandRegistry.Handler { payload, system in
            try await handle(try PayloadDecoder.decode(C.self, from: payload), system)
        }
    }

    #if canImport(SwiftUI)
    /// Registers a screen. `parameters` are the names of the route parameters it needs; `screen` builds it
    /// from a route, and throws if the route's parameters don't fit (it then shows as an invalid link).
    public mutating func route<Screen: View>(
        _ name: String,
        title: String,
        parameters: [String] = [],
        screen: @escaping @MainActor @Sendable (Route, AppSystem) throws -> Screen
    ) {
        guard routes[name] == nil else { return problems.append("Route \(name) is registered twice") }
        routes[name] = RouteEntry(name: name, title: title, parameters: parameters) { route, system in
            AnyView(try screen(route, system))
        }
    }
    #endif

    /// Registers an automation. `start` is called whenever the app becomes active; the automation is
    /// stopped when the app goes to the background. Pass `onError: system.reportError` to `automation`.
    public mutating func automation(
        _ name: String,
        start: @escaping @Sendable (AppSystem) async throws -> Automation
    ) {
        addComponent(name) { system in
            let automation = try await start(system)
            return RunningComponent { automation.stop() }
        }
    }

    /// Registers a persisted view. `start` is called whenever the app becomes active (the view resumes
    /// after its checkpoint); the view is closed when the app goes to the background.
    public mutating func persistedView<A: PersistedAccumulator>(
        _ name: String,
        start: @escaping @Sendable (AppSystem) async throws -> PersistedViewHandle<A>
    ) {
        addComponent(name) { system in
            let handle = try await start(system)
            return RunningComponent { await handle.close() }
        }
    }

    /// Registers a schema change of the app's own tables, e.g. a persisted view's read model.
    /// `id` must be unique and never change once shipped: `"{context}/{slice}/v1"`.
    public mutating func migration(_ id: String, _ migrate: @escaping @Sendable (Database) throws -> Void) {
        guard !migrations.contains(where: { $0.id == id }) else {
            return problems.append("Migration \(id) is registered twice")
        }
        migrations.append(Migration(id: id, migrate: migrate))
    }

    /// Declares a configuration key the slice needs. The live app doesn't start without it;
    /// tests and previews use `testValue`.
    public mutating func requireConfig(_ key: String, testValue: String) {
        configTestValues[key] = testValue
    }

    /// Declares that slice `from` sends the command `name`, so the full test suite can check that every
    /// command a screen sends is registered once all slices are built.
    public mutating func uses(command name: String, from slice: String) {
        usedCommands[slice, default: []].insert(name)
    }

    /// Declares that slice `from` links or navigates to the screen `name`.
    public mutating func uses(route name: String, from slice: String) {
        usedRoutes[slice, default: []].insert(name)
    }

    private mutating func addComponent(
        _ name: String,
        start: @escaping @Sendable (AppSystem) async throws -> RunningComponent
    ) {
        guard !components.contains(where: { $0.name == name }) else {
            return problems.append("Component \(name) is registered twice")
        }
        components.append(Component(name: name, start: start))
    }
}

public struct RegistryError: Error, Equatable, CustomStringConvertible {
    public let problems: [String]
    public var description: String { problems.joined(separator: "\n") }
}

/// A name a slice refers to that no slice has registered.
public struct UnresolvedReference: Equatable, Sendable, CustomStringConvertible {
    public enum Kind: String, Sendable { case command, route }
    public let kind: Kind
    public let name: String
    public let usedBy: String
    public var description: String { "\(usedBy) uses the \(kind.rawValue) \(name), which is not registered" }
}
