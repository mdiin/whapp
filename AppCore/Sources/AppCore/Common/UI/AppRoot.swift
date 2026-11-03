#if canImport(SwiftUI)
import SwiftUI

/// The app's whole UI: starts the system, then shows `RootView`, and runs the lifecycle along with the
/// scene phase (components and screens stop in the background and start again when active).
///
/// The app target's `@main` only does `WindowGroup { AppRoot { AppConfig(infoDictionary: ...) } }`.
public struct AppRoot: View {
    private enum Boot {
        case loading
        case failed(String)
        case ready(Lifecycle)
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var boot = Boot.loading
    private let config: @Sendable () -> AppConfig

    public init(config: @escaping @Sendable () -> AppConfig) {
        self.config = config
    }

    public var body: some View {
        Group {
            switch boot {
            case .loading:
                ProgressView()
                    .task { await start() }
            case .failed(let message):
                ContentUnavailableView(
                    "The app could not start", systemImage: "exclamationmark.triangle", description: Text(message))
            case .ready(let lifecycle):
                RootView(system: lifecycle.system)
            }
        }
        .onChange(of: scenePhase) { _, phase in apply(phase) }
        // `scenePhase` may have become .active while booting (ignored then): apply the current one now.
        .onChange(of: isReady) { _, ready in if ready { apply(scenePhase) } }
    }

    private var isReady: Bool {
        if case .ready = boot { return true }
        return false
    }

    private func start() async {
        do {
            let system = try await AppSystem.live(config: config())
            let lifecycle = Lifecycle(system: system)
            boot = .ready(lifecycle)
        } catch {
            boot = .failed(String(describing: error))
        }
    }

    private func apply(_ phase: ScenePhase) {
        guard case .ready(let lifecycle) = boot else { return }
        switch phase {
        case .active: lifecycle.start()
        case .background: lifecycle.stop()
        default: break  // .inactive is brief (an alert, the app switcher): keep running
        }
    }
}
#endif
