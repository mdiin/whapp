import Foundation
import GRDB
import Ledjer
import LedjerGRDB
import Testing

@testable import AppCore

// The helpers the build skills use, exercised the way slices use them.

private struct TaskAdded: Event {
    static let eventType: EventType = "scaffold-test/task-added"
    static var tags: [EventTag<Self>] { [EventTag("listId", \.listId), EventTag("taskId", \.taskId)] }
    var listId: UUID
    var taskId: UUID
    var title: String
}

private struct TaskDone: Event {
    static let eventType: EventType = "scaffold-test/task-done"
    static var tags: [EventTag<Self>] { [EventTag("listId", \.listId), EventTag("taskId", \.taskId)] }
    var listId: UUID
    var taskId: UUID
}

private let openTasks = ReadModel(initial: [UUID: String](), bindings: [
    .on(TaskAdded.self) { tasks, event in tasks[event.taskId] = event.title },
    .on(TaskDone.self) { tasks, event in tasks[event.taskId] = nil },
])

private func completeTask(listId: UUID, taskId: UUID, store: any EventStore) async throws {
    let decision = try await openTasks.decide(on: store, where: [.payload("listId"): .bound(listId)])
    guard decision.state[taskId] != nil else { throw CommandRejected("The task is not open") }
    try await store.append([TaskDone(listId: listId, taskId: taskId)], condition: decision.condition)
}

@Suite struct ReadModelTests {
    let list = UUID()
    let task = UUID()

    @Test func decidesOnTheReadModel() async throws {
        try await gwt(
            given: [TaskAdded(listId: list, taskId: task, title: "Buy milk")],
            when: { try await completeTask(listId: list, taskId: task, store: $0) },
            then: [TaskDone(listId: list, taskId: task)])
        try await gwt(
            given: [TaskAdded(listId: list, taskId: task, title: "Buy milk"), TaskDone(listId: list, taskId: task)],
            when: { try await completeTask(listId: list, taskId: task, store: $0) },
            thenThrows: { $0 as? CommandRejected == CommandRejected("The task is not open") })
    }

    @Test func conditionFailsWhenTheStateChangedMeanwhile() async throws {
        let store = InMemoryEventStore()
        try await store.append([TaskAdded(listId: list, taskId: task, title: "Buy milk")])
        let decision = try await openTasks.decide(on: store, where: [.payload("listId"): .bound(list)])
        try await store.append([TaskDone(listId: list, taskId: task)])
        await #expect(throws: LedjerError.self) {
            try await store.append([TaskDone(listId: list, taskId: task)], condition: decision.condition)
        }
    }

    @Test @MainActor func screensFollowTheReadModel() async throws {
        let system = try await AppSystem.inMemory(given: [TaskAdded(listId: list, taskId: task, title: "Buy milk")])
        let live = LiveValue(system, openTasks, where: [.payload("listId"): .bound(list)])
        await live.refresh()
        #expect(live.value == [task: "Buy milk"])

        let broken = LiveValue(system, openTasks, where: [.payload("nope"): .bound(list)])
        await broken.refresh()
        #expect(broken.value == nil)
        #expect(broken.failure != nil)
    }

    @Test func automationsRunOnStart() async throws {
        let store = InMemoryEventStore()
        let ran = Counter()
        let running = try await automation(on: store, triggers: [.onStart, .event(TaskAdded.self)]) { _ in
            ran.increment()
        }
        defer { running.stop() }
        for _ in 0..<100 where ran.value == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(ran.value == 1)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}

// MARK: - A persisted view, registered as a slice registers it

private enum TaskTitles {
    static let name = "scaffold-test/task-titles"

    static let view = PersistedStateView<GRDBOperation>(bindings: [
        .on(TaskAdded.self) { event in
            [GRDBOperation { db in
                try db.execute(
                    sql: "INSERT INTO scaffold_task_titles (taskId, title) VALUES (?, ?)",
                    arguments: [event.taskId.uuidString, event.title])
            }]
        },
        .on(TaskDone.self) { event in
            [GRDBOperation { db in
                try db.execute(sql: "DELETE FROM scaffold_task_titles WHERE taskId = ?", arguments: [event.taskId.uuidString])
            }]
        },
    ])

    static func titles(_ db: Database) throws -> [String] {
        try String.fetchAll(db, sql: "SELECT title FROM scaffold_task_titles ORDER BY title")
    }

    static func register(in registry: inout Registry) {
        registry.migration("\(name)/v1") { db in
            try db.create(table: "scaffold_task_titles") { t in
                t.primaryKey("taskId", .text)
                t.column("title", .text).notNull()
            }
        }
        registry.persistedView(name) { system in
            let accumulator = try await GRDBAccumulator.open(name: name, writer: system.database)
            var options = PersistedViewOptions()
            options.onError = system.reportError
            return try await view.start(on: system.store, accumulator: accumulator, options: options)
        }
    }
}

@Suite struct PersistedViewTests {
    @Test func reducesIntoItsTables() async throws {
        let system = try await AppSystem.inMemory(register: TaskTitles.register(in:))
        let list = UUID()
        let (a, b) = (UUID(), UUID())
        try await gt(
            view: TaskTitles.view,
            accumulator: try GRDBAccumulator(name: TaskTitles.name, writer: system.database),
            given: [
                TaskAdded(listId: list, taskId: a, title: "Walk the dog"),
                TaskAdded(listId: list, taskId: b, title: "Buy milk"),
                TaskDone(listId: list, taskId: a),
            ],
            then: { _ in try await system.database.read(TaskTitles.titles) == ["Buy milk"] })
    }

    @Test @MainActor func runsWithTheLifecycleAndScreensObserveIt() async throws {
        let system = try await AppSystem.inMemory(register: TaskTitles.register(in:))
        let lifecycle = Lifecycle(system: system)
        lifecycle.start()
        await lifecycle.settle()
        let live = LiveValue(system, observing: TaskTitles.titles)
        let running = Task { await live.run() }
        defer { running.cancel() }

        try await system.store.append([TaskAdded(listId: UUID(), taskId: UUID(), title: "Buy milk")])
        for _ in 0..<200 where live.value != ["Buy milk"] { try await Task.sleep(for: .milliseconds(10)) }
        #expect(live.value == ["Buy milk"])

        lifecycle.stop()
        await lifecycle.settle()
    }
}
