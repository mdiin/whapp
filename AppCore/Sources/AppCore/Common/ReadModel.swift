import Foundation
import Ledjer

/// A ledjer `StateView` that also knows the event types it reads, so the same definition serves
///
/// - a command's consistency check (`decide(on:where:)`: the state plus the append condition),
/// - a screen that follows it (`LiveValue(system, model, where:)`),
/// - an automation's to-do list and tests (`run(on:where:)`).
///
/// ```swift
/// static let cartItems = ReadModel(initial: [UUID: Item](), bindings: [
///     .on(ItemAdded.self) { items, event in items[event.itemId] = Item(...) },
///     .on(ItemRemoved.self) { items, event in items[event.itemId] = nil },
/// ])
/// ```
public struct ReadModel<State: Sendable>: Sendable {
    /// One reducer: an event type, optionally narrowed by tag values, and how it changes the state.
    public struct Binding: Sendable {
        let eventType: any Event.Type
        let binding: StateViewBinding<State>

        public static func on<E: Event>(
            _ type: E.Type,
            where tagBindings: TagBindings = [:],
            reduce: @escaping @Sendable (inout State, E) throws -> Void
        ) -> Binding {
            Binding(eventType: type, binding: .on(type, where: tagBindings, reduce: reduce))
        }

        /// Like `on(_:where:reduce:)`, with the stored event (position, metadata) too.
        public static func on<E: Event>(
            _ type: E.Type,
            where tagBindings: TagBindings = [:],
            reduce: @escaping @Sendable (inout State, E, StoredEvent) throws -> Void
        ) -> Binding {
            Binding(eventType: type, binding: .on(type, where: tagBindings, reduce: reduce))
        }
    }

    public let view: StateView<State>
    public let eventTypes: [any Event.Type]

    public init(initial: State, bindings: [Binding]) {
        self.view = StateView(initial: initial, bindings: bindings.map(\.binding))
        var seen = Set<ObjectIdentifier>()
        self.eventTypes = bindings.map(\.eventType).filter { seen.insert(ObjectIdentifier($0)).inserted }
    }

    /// Reduces the events, narrowed by `tagBindings` (e.g. `[.payload("cartId"): .bound(cartId)]`).
    public func run(on store: any EventStore, where tagBindings: TagBindings = [:]) async throws -> State {
        try await view.run(on: store, where: tagBindings)
    }

    /// The events this read model reads with `tagBindings`, for following it or for an append condition.
    public func query(where tagBindings: TagBindings = [:]) throws -> EventQuery {
        EventQuery(try EventQueryItem(eventTypes, where: tagBindings))
    }

    /// The state a command decides on, and the condition for its append: it fails with
    /// `LedjerError.appendConditionFailed` if an event this read model reads was appended after the state was read.
    public func decide(on store: any EventStore, where tagBindings: TagBindings = [:]) async throws -> Decision<State> {
        let query = try query(where: tagBindings)
        // Read the position first: an event appended between the two reads then fails the append,
        // where reading it second could let one slip by unseen.
        let position = try await store.lastPosition(matching: query, through: .max)
        let state = try await run(on: store, where: tagBindings)
        return Decision(state: state, condition: AppendCondition(query: query, after: position))
    }
}

/// What a command decides on: the state, and the condition to append with.
public struct Decision<State: Sendable>: Sendable {
    public let state: State
    public let condition: AppendCondition
}

extension LiveValue {
    /// Follows a read model, narrowed by `tagBindings`, refreshing whenever one of its events arrives.
    public convenience init(_ system: AppSystem, _ model: ReadModel<Value>, where tagBindings: TagBindings = [:]) {
        do {
            let query = try model.query(where: tagBindings)
            self.init(system, refreshOn: query) { store in try await model.run(on: store, where: tagBindings) }
        } catch {
            self.init(system, failing: error)
        }
    }
}

extension Trigger {
    /// Fires once, when the automation starts. Automations start whenever the app becomes active, so this
    /// makes them process what is still on their to-do list from before (event triggers only fire for
    /// new events).
    public static var onStart: Trigger {
        .signal {
            AsyncStream { continuation in
                continuation.yield()
                continuation.finish()
            }
        }
    }
}
