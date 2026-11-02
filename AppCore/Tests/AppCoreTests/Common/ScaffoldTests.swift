import Foundation
import GRDB
import Ledjer
import LedjerGRDB
import Testing

@testable import AppCore

// Tests of the scaffold in `Common/` itself, with registrations of their own.

private struct CounterIncremented: Event {
    static let eventType: EventType = "scaffold-test/counter-incremented"
    static var tags: [EventTag<Self>] { [EventTag("counterId", \.counterId)] }
    var counterId: UUID
    var by: Int
}

private struct Increment: Codable, Sendable {
    var counterId: UUID
    var by: Int
    var note: String?
}

private func counterQuery(_ id: UUID) throws -> EventQuery {
    try EventQuery.of(CounterIncremented.self, where: [.payload("counterId"): .bound(id)])
}

private let counterView = StateView(initial: 0, bindings: [
    .on(CounterIncremented.self) { total, event in total += event.by }
])

private func registerCounter(in registry: inout Registry) {
    registry.command("scaffold-test/increment", Increment.self) { command, system in
        guard command.by > 0 else { throw CommandRejected("Only positive increments") }
        if command.by == 13 { throw ExampleBug() }
        try await system.store.append([CounterIncremented(counterId: command.counterId, by: command.by)])
    }
}

private struct ExampleBug: Error {}

// MARK: - Payloads

@Suite struct PayloadTests {
    private struct Example: Codable, Equatable {
        var id: UUID
        var name: String
        var count: Int
        var price: Decimal
        var ratio: Double
        var done: Bool
        var day: CalendarDate
        var at: Date
        var tags: [String]
        var note: String?
    }

    @Test func decodesEveryFieldType() throws {
        let id = UUID()
        let at = Date(timeIntervalSinceReferenceDate: 1000.5)
        let decoded = try PayloadDecoder.decode(Example.self, from: [
            "id": .uuid(id), "name": "a", "count": 3, "price": .decimal(Decimal(string: "19.99")!), "ratio": 0.5,
            "done": true, "day": .date(CalendarDate("2026-11-02")!), "at": .dateTime(at), "tags": ["x", "y"],
            "note": nil,
        ])
        #expect(decoded == Example(id: id, name: "a", count: 3, price: Decimal(string: "19.99")!, ratio: 0.5,
                                   done: true, day: CalendarDate("2026-11-02")!, at: at, tags: ["x", "y"], note: nil))
    }

    @Test func namesTheFieldsThatDontFit() throws {
        #expect(throws: CommandInputError(fieldErrors: ["counterId": ["is required"]])) {
            try PayloadDecoder.decode(Increment.self, from: ["by": 1])
        }
        #expect(throws: CommandInputError(fieldErrors: ["by": ["is not valid"]])) {
            try PayloadDecoder.decode(Increment.self, from: ["counterId": .uuid(UUID()), "by": "one"])
        }
    }
}

// MARK: - Calendar dates

@Suite struct CalendarDateTests {
    @Test func parsesAndPrints() throws {
        #expect(CalendarDate("2026-02-28")?.description == "2026-02-28")
        #expect(CalendarDate("2026-02-30") == nil)
        #expect(CalendarDate("2026-2-3") == nil)
        #expect(CalendarDate(year: 2026, month: 1, day: 5)?.description == "2026-01-05")
    }

    @Test func isTheDayInTheGivenZone() throws {
        let instant = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01T00:00:00Z
        #expect(CalendarDate(instant, in: TimeZone(identifier: "UTC")!).description == "2026-01-01")
        #expect(CalendarDate(instant, in: TimeZone(identifier: "America/New_York")!).description == "2025-12-31")
    }

    @Test func roundTripsAsJSONString() throws {
        let date = CalendarDate("2026-11-02")!
        let data = try JSONEncoder().encode([date])
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-11-02\"]")
        #expect(try JSONDecoder().decode([CalendarDate].self, from: data) == [date])
    }
}

// MARK: - Registry and commands

@Suite struct CommandTests {
    @Test func sendsARegisteredCommand() async throws {
        let system = try await AppSystem.inMemory(register: registerCounter)
        let id = UUID()
        try await system.send("scaffold-test/increment", ["counterId": .uuid(id), "by": 2])
        #expect(try await counterView.run(on: system.store, where: [.payload("counterId"): .bound(id)]) == 2)
    }

    @Test func turnsFailuresIntoFormErrors() async throws {
        let reported = Reported()
        let system = try AppSystem(
            config: AppConfig(), store: InMemoryEventStore(), database: try AppDatabase.inMemory(),
            requireConfig: false, reportError: { reported.add($0) }, register: registerCounter)

        func errors(_ payload: CommandPayload, _ name: String = "scaffold-test/increment") async -> CommandErrors {
            do {
                try await system.send(name, payload)
                return .none
            } catch {
                return CommandErrors(error)
            }
        }

        let id = FieldValue.uuid(UUID())
        #expect(await errors(["counterId": id, "by": -1]) == CommandErrors(general: ["Only positive increments"]))
        #expect(await errors(["by": 1]) == CommandErrors(fields: ["counterId": ["is required"]]))
        #expect(await errors([:], "scaffold-test/unknown") == CommandErrors(general: ["This action is not available yet."]))
        #expect(reported.count == 0)
        #expect(await errors(["counterId": id, "by": 13]) == CommandErrors(general: ["Something went wrong. Please try again."]))
        #expect(reported.count == 1)
    }

    @Test func rejectsDuplicateNames() async throws {
        await #expect(throws: RegistryError.self) {
            _ = try await AppSystem.inMemory { registry in
                registerCounter(in: &registry)
                registerCounter(in: &registry)
            }
        }
    }

    @Test func requiresConfigOnlyWhenLive() async throws {
        let register = { @Sendable (registry: inout Registry) in
            registry.requireConfig("API_BASE_URL", testValue: "https://example.test")
        }
        #expect(throws: AppConfigError.missing(["API_BASE_URL"])) {
            _ = try AppSystem(config: AppConfig(values: ["API_BASE_URL": ""]), store: InMemoryEventStore(),
                              database: try AppDatabase.inMemory(), requireConfig: true, register: register)
        }
        let system = try await AppSystem.inMemory(register: register)
        #expect(try system.config.url("API_BASE_URL") == URL(string: "https://example.test"))
    }

    @Test func readsConfigFromInfoPlist() throws {
        let config = AppConfig(infoDictionary: ["AppConfig": ["API_BASE_URL": "https://api.example.com", "N": 1]])
        #expect(try config.string("API_BASE_URL") == "https://api.example.com")
        #expect(throws: AppConfigError.missing(["N"])) { try config.string("N") }
    }

    @Test func listsUnresolvedReferences() async throws {
        let system = try await AppSystem.inMemory { registry in
            registerCounter(in: &registry)
            registry.uses(command: "scaffold-test/increment", from: "scaffold-test/counter")
            registry.uses(command: "scaffold-test/reset", from: "scaffold-test/counter")
            registry.uses(route: "scaffold-test/history", from: "scaffold-test/counter")
        }
        #expect(system.unresolvedReferences.map(\.name) == ["scaffold-test/history", "scaffold-test/reset"])
    }

    @Test func appliesMigrations() async throws {
        let system = try await AppSystem.inMemory { registry in
            registry.migration("scaffold-test/totals/v1") { db in
                try db.create(table: "scaffold_totals") { t in
                    t.primaryKey("counterId", .text)
                    t.column("total", .integer).notNull()
                }
            }
        }
        #expect(try await system.database.read { try $0.tableExists("scaffold_totals") })
    }
}

private final class Reported: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [any Error] = []
    func add(_ error: any Error) { lock.withLock { errors.append(error) } }
    var count: Int { lock.withLock { errors.count } }
}

// MARK: - Navigation

@MainActor
@Suite struct NavigatorTests {
    @Test func pushesNewScreensAndGoesBackToKnownOnes() {
        let list = Route("shop/cart-items", ["cartId": "c1"])
        let checkout = Route("shop/checkout", ["cartId": "c1"])
        let navigator = Navigator(path: [list], sheet: Route("shop/add-item"))
        navigator.navigate(to: checkout)
        #expect(navigator.path == [list, checkout])
        #expect(navigator.sheet == nil)
        navigator.navigate(to: list)
        #expect(navigator.path == [list])
    }
}

// MARK: - Lifecycle and live values

private actor Log {
    var entries: [String] = []
    func add(_ entry: String) { entries.append(entry) }
}

@MainActor
@Suite struct LifecycleTests {
    @Test func startsAndStopsComponentsWithTheApp() async throws {
        let log = Log()
        let system = try await AppSystem.inMemory { registry in
            registry.automation("scaffold-test/doubler") { system in
                await log.add("start")
                return try await automation(on: system.store, triggers: [.event(CounterIncremented.self)],
                                            onError: system.reportError) { _ in }
            }
        }
        let lifecycle = Lifecycle(system: system)
        lifecycle.start()
        await lifecycle.settle()
        #expect(system.activity.isActive)
        lifecycle.stop()
        lifecycle.start()  // a quick background → active
        await lifecycle.settle()
        #expect(await log.entries == ["start", "start"])
        lifecycle.stop()
        await lifecycle.settle()
        #expect(!system.activity.isActive)
    }

    @Test func liveValueFollowsEventsWhileActive() async throws {
        let id = UUID()
        let system = try await AppSystem.inMemory(given: [CounterIncremented(counterId: id, by: 1)])
        let live = LiveValue(system, refreshOn: try counterQuery(id)) { store in
            try await counterView.run(on: store, where: [.payload("counterId"): .bound(id)])
        }
        await live.refresh()
        #expect(live.value == 1)

        system.activity.set(true)
        let running = Task { await live.run() }
        defer { running.cancel() }
        try await eventually { live.value == 1 }
        try await system.store.append([CounterIncremented(counterId: id, by: 2)])
        try await eventually { live.value == 3 }

        system.activity.set(false)
        try await Task.sleep(for: .milliseconds(50))
        try await system.store.append([CounterIncremented(counterId: id, by: 4)])
        try await Task.sleep(for: .milliseconds(50))
        #expect(live.value == 3)  // paused in the background
        system.activity.set(true)
        try await eventually { live.value == 7 }  // catches up when active again
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Condition not met within 1 s")
    }
}
