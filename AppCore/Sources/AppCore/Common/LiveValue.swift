import Foundation
import GRDB
import Ledjer
import Observation

/// A screen's read model, kept up to date while the screen is shown and the app is active.
///
/// Two sources:
/// - a state view: `load` runs it on the event store, again whenever an event of `refreshOn` arrives;
/// - a persisted view's tables: `fetch` reads them, again whenever they change (GRDB `ValueObservation`).
///
/// A screen starts it with `.task { await live.run() }`, which ends when the screen goes away. While the
/// app is in the background it doesn't follow anything; when it becomes active again it loads afresh,
/// so nothing is missed. Tests and previews call `refresh()` instead.
@MainActor
@Observable
public final class LiveValue<Value: Sendable> {
    /// `nil` until loaded.
    public private(set) var value: Value?
    /// Why the last load failed, if it did. Cleared by the next successful one.
    public private(set) var failure: (any Error)?

    @ObservationIgnored private let system: AppSystem
    @ObservationIgnored private let source: Source

    private enum Source: Sendable {
        case events(EventQuery, @Sendable (any EventStore) async throws -> Value)
        case database(@Sendable (Database) throws -> Value)
        case failed(any Error)
    }

    /// Runs `load` on the event store, again for every new event `refreshOn` matches.
    ///
    /// `refreshOn` should select what the state view reads, e.g.
    /// `try EventQuery.of(ItemAdded.self, ItemRemoved.self, where: [.payload("cartId"): .bound(cartId)])`.
    public init(
        _ system: AppSystem,
        refreshOn query: EventQuery,
        load: @escaping @Sendable (any EventStore) async throws -> Value
    ) {
        self.system = system
        self.source = .events(query, load)
    }

    /// Reads a persisted view's tables with `fetch`, again whenever they change.
    public init(_ system: AppSystem, observing fetch: @escaping @Sendable (Database) throws -> Value) {
        self.system = system
        self.source = .database(fetch)
    }

    /// A value that can't be loaded, e.g. because its query is invalid: it only ever shows `failure`.
    init(_ system: AppSystem, failing error: any Error) {
        self.system = system
        self.source = .failed(error)
        self.failure = error
    }

    /// Loads the value once.
    public func refresh() async {
        do {
            let value: Value
            switch source {
            case .events(_, let load): value = try await load(system.store)
            case .database(let fetch): value = try await system.database.read(fetch)
            case .failed(let error): throw error
            }
            self.value = value
            self.failure = nil
        } catch {
            if !Task.isCancelled { self.failure = error }
        }
    }

    /// Follows the value while the app is active, until the calling task is cancelled.
    public func run() async {
        var following: Task<Void, Never>?
        for await active in system.activity.changes() {
            following?.cancel()
            following = active ? Task { await self.follow() } : nil
        }
        following?.cancel()
    }

    private func follow() async {
        do {
            switch source {
            case .events(let query, _):
                // Subscribe before loading, so an event appended in between isn't missed.
                let events = try await system.store.subscribe(query)
                await refresh()
                for try await _ in events { await refresh() }
            case .database(let fetch):
                for try await value in ValueObservation.tracking(fetch).values(in: system.database) {
                    self.value = value
                    self.failure = nil
                }
            case .failed(let error):
                throw error
            }
        } catch {
            if !Task.isCancelled { self.failure = error }
        }
    }
}
