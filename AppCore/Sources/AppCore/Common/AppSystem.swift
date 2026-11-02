import Foundation
import GRDB
import Ledjer
import LedjerGRDB

/// The composition root: everything slices need, built once at launch.
///
/// Screens get it from their route; commands, automations and persisted views from the registry.
/// Tests and previews build one with `inMemory(given:)`.
public final class AppSystem: Sendable {
    public let config: AppConfig
    public let store: any EventStore
    /// The database of the events (live) and of the persisted views' read models.
    public let database: any DatabaseWriter
    public let commands: CommandRegistry
    public let routes: RouteRegistry
    public let components: [Component]
    /// Whether the app is active. Screens follow their events only while it is.
    public let activity: Activity
    /// Where failures that aren't the user's go: of commands, automations and persisted views.
    public let reportError: @Sendable (any Error) -> Void

    let usedCommands: [String: Set<String>]
    let usedRoutes: [String: Set<String>]

    /// Builds the system from the slices' registrations, and applies their migrations.
    ///
    /// Throws `RegistryError` if a name is registered twice. With `requireConfig`, also throws
    /// `AppConfigError.missing` for required keys `config` lacks; otherwise those get their test values.
    public init(
        config: AppConfig,
        store: any EventStore,
        database: any DatabaseWriter,
        requireConfig: Bool,
        reportError: @escaping @Sendable (any Error) -> Void = ErrorReporter.default,
        register: (inout Registry) -> Void = Slices.register(in:)
    ) throws {
        var registry = Registry()
        register(&registry)
        guard registry.problems.isEmpty else { throw RegistryError(problems: registry.problems) }
        if requireConfig {
            let missing = config.missing(registry.configTestValues.keys)
            guard missing.isEmpty else { throw AppConfigError.missing(missing) }
            self.config = config
        } else {
            self.config = config.filling(registry.configTestValues)
        }
        try AppDatabase.migrate(database, migrations: registry.migrations)
        self.store = store
        self.database = database
        self.commands = CommandRegistry(handlers: registry.commands)
        self.routes = RouteRegistry(entries: registry.routes)
        self.components = registry.components
        self.usedCommands = registry.usedCommands
        self.usedRoutes = registry.usedRoutes
        self.reportError = reportError
        self.activity = Activity()
    }

    /// The system of the running app: events and read models in a SQLite database in Application Support.
    public static func live(
        config: AppConfig,
        fileProtection: DatabaseFileProtection = .default
    ) async throws -> AppSystem {
        let pool = try await AppDatabase.openLive(fileProtection: fileProtection)
        let store = try await GRDBEventStore.open(pool)
        return try await Task.detached {
            try AppSystem(config: config, store: store, database: pool, requireConfig: true)
        }.value
    }

    /// A system in memory, for tests and previews, with `given` events already appended.
    /// Required configuration keys that `config` lacks get their test values.
    public static func inMemory(
        given: [any Event] = [],
        config: AppConfig = AppConfig(),
        register: @Sendable (inout Registry) -> Void = Slices.register(in:)
    ) async throws -> AppSystem {
        let store = InMemoryEventStore()
        try await store.append(given)
        return try AppSystem(
            config: config, store: store, database: try AppDatabase.inMemory(), requireConfig: false,
            register: register)
    }

    /// Sends the command registered as `name`.
    ///
    /// Throws `CommandRejected` (a business rule), `CommandInputError` (the payload doesn't fit),
    /// `CommandNotRegistered`, or `CommandFailed` (anything else, already reported). Turn the error into
    /// what the form shows with `CommandErrors(error)`.
    public func send(_ name: String, _ payload: CommandPayload) async throws {
        try await commands.send(name, payload, system: self)
    }

    /// The commands and screens slices use that no slice has registered. Empty once every slice is built.
    public var unresolvedReferences: [UnresolvedReference] {
        let commands = usedCommands.flatMap { slice, names in
            names.filter { !self.commands.isRegistered($0) }.map { UnresolvedReference(kind: .command, name: $0, usedBy: slice) }
        }
        let routes = usedRoutes.flatMap { slice, names in
            names.filter { !self.routes.isRegistered($0) }.map { UnresolvedReference(kind: .route, name: $0, usedBy: slice) }
        }
        return (commands + routes).sorted { ($0.usedBy, $0.name) < ($1.usedBy, $1.name) }
    }
}
