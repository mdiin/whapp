import Foundation
import Ledjer
import Testing

@testable import AppCore

/// Checks over the whole app: every slice's registrations and events together.
@Suite struct SystemTests {
    @Test func everySliceRegistersWithoutConflicts() async throws {
        _ = try await AppSystem.inMemory()
    }

    @Test func eventTypesAreUnique() {
        var seen: [EventType: String] = [:]
        for type in AllEvents.types {
            let name = String(reflecting: type)
            if let other = seen[type.eventType] {
                Issue.record("\(type.eventType) is declared by both \(other) and \(name)")
            }
            seen[type.eventType] = name
        }
    }

    @Test func eventsAreListedOnce() {
        let names = AllEvents.types.map { String(reflecting: $0) }
        #expect(names.count == Set(names).count, "AllEvents lists a type more than once")
    }

    /// While slices are still being built, a screen may use a command or screen that doesn't exist yet;
    /// that is expected, so this only fails with `APP_STRICT_REFERENCES=1`, e.g. once every slice is built.
    @Test func everyUsedCommandAndScreenIsRegistered() async throws {
        let unresolved = try await AppSystem.inMemory().unresolvedReferences
        guard !unresolved.isEmpty else { return }
        let report = unresolved.map(\.description).joined(separator: "\n")
        if ProcessInfo.processInfo.environment["APP_STRICT_REFERENCES"] == "1" {
            Issue.record("Unresolved references:\n\(report)")
        } else {
            print("Unresolved references (not built yet?):\n\(report)")
        }
    }
}
