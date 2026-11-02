import Foundation
import GRDB
import LedjerGRDB

/// When iOS keeps the database files encrypted. The project chooses; see the README.
public enum DatabaseFileProtection: Sendable {
    /// Readable only while the device is unlocked. Anything that runs while it is locked fails.
    case complete
    /// Files already open stay readable when the device locks.
    case completeUnlessOpen
    /// Readable from the first unlock after the device starts. The iOS default, and the kit's.
    case completeUntilFirstUserAuthentication
    case none

    public static let `default` = DatabaseFileProtection.completeUntilFirstUserAuthentication
}

/// A schema change of the app's own tables, e.g. a persisted view's read model.
public struct Migration: Sendable {
    /// Unique and never changed once shipped, e.g. `"orders/order-list/v1"`.
    public let id: String
    let migrate: @Sendable (Database) throws -> Void
}

/// Opens the app's SQLite database: the events and the persisted views' read models.
public enum AppDatabase {
    /// The database file in Application Support, which is included in the device's backups.
    /// In an offline-first app the events are the only copy of the user's data: keep it that way.
    public static func openLive(
        fileName: String = "app.sqlite",
        fileProtection: DatabaseFileProtection = .default
    ) async throws -> DatabasePool {
        try await Task.detached {
            let directory = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Database", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent(fileName)
            let pool = try DatabasePool(path: file.path)
            try protect([directory, file, URL(fileURLWithPath: file.path + "-wal"), URL(fileURLWithPath: file.path + "-shm")],
                        with: fileProtection)
            return pool
        }.value
    }

    /// A database in memory, for tests and previews.
    public static func inMemory() throws -> DatabaseQueue {
        try DatabaseQueue()
    }

    /// Applies the ledjer migrations and the slices' migrations, in registration order.
    static func migrate(_ writer: any DatabaseWriter, migrations: [Migration]) throws {
        var migrator = DatabaseMigrator()
        GRDBEventStore.registerMigrations(in: &migrator)
        for migration in migrations {
            migrator.registerMigration(migration.id) { db in try migration.migrate(db) }
        }
        try migrator.migrate(writer)
    }

    /// Sets the protection class of the database files, the `-wal` and `-shm` files included.
    private static func protect(_ urls: [URL], with protection: DatabaseFileProtection) throws {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let type: FileProtectionType =
            switch protection {
            case .complete: .complete
            case .completeUnlessOpen: .completeUnlessOpen
            case .completeUntilFirstUserAuthentication: .completeUntilFirstUserAuthentication
            case .none: .none
            }
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.setAttributes([.protectionKey: type], ofItemAtPath: url.path)
        }
        #endif
    }
}
