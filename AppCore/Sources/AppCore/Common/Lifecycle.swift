import Foundation

/// Whether the app is active, for whatever should only run then (screens following their events).
@MainActor
public final class Activity {
    public private(set) var isActive = false
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    nonisolated public init() {}

    func set(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        for continuation in continuations.values { continuation.yield(active) }
    }

    /// The current state, then every change, until the iterating task is cancelled.
    public func changes() -> AsyncStream<Bool> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.yield(isActive)
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }
}

/// Starts the components (automations, persisted views) when the app becomes active and stops them when
/// it goes to the background, and tells `AppSystem.activity`.
///
/// Starting waits for the previous stop to finish, so a quick background → active never runs two
/// copies of a persisted view against one checkpoint. (This is the pattern of ledjer-swift's README,
/// "Backgrounding on iOS".) A component that fails to start, or fails later, is reported to
/// `AppSystem.reportError`; it is started again the next time the app becomes active.
@MainActor
public final class Lifecycle {
    public let system: AppSystem
    private var wanted = false
    private var running: [RunningComponent] = []
    private var starting: Task<Void, Never>?
    private var stopping: Task<Void, Never>?

    public init(system: AppSystem) {
        self.system = system
    }

    public func start() {
        guard !wanted else { return }
        wanted = true
        system.activity.set(true)
        let previous = stopping  // captured now: by the time the task runs, `stopping` may be a later stop
        starting = Task {
            await previous?.value
            for component in system.components {
                if Task.isCancelled { break }  // a stop() came in; what started so far is in `running`
                do {
                    running.append(try await component.start(system))
                } catch {
                    if !Task.isCancelled { system.reportError(ComponentError(component: component.name, underlying: error)) }
                }
            }
        }
    }

    public func stop() {
        guard wanted else { return }
        wanted = false
        system.activity.set(false)
        let start = starting
        start?.cancel()
        let previous = stopping
        stopping = Task {
            await start?.value  // an unfinished start ends first, leaving what it started in `running`
            await previous?.value
            let current = running
            running = []
            for component in current.reversed() { await component.stop() }
        }
    }

    /// Waits until the last `start()` and `stop()` have finished. For tests.
    public func settle() async {
        await starting?.value
        await stopping?.value
    }
}

public struct ComponentError: Error, CustomStringConvertible {
    public let component: String
    public let underlying: any Error
    public var description: String { "\(component) failed to start: \(underlying)" }
}
