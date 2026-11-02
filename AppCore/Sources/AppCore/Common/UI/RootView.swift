#if canImport(SwiftUI)
import SwiftUI

/// The app's navigation structure.
///
/// The kit only navigates within a timeline; the app's top-level structure (start screen, tabs, sidebar)
/// is the project's decision. Until the project replaces it, this shows the "Screens" catalog of every
/// registered screen, so each one can be reached. Keep the `navigationDestination` and the `sheet` when
/// replacing it: they are how every screen is shown.
public struct RootView: View {
    private let system: AppSystem
    @State private var navigator = Navigator()

    public init(system: AppSystem) {
        self.system = system
    }

    public var body: some View {
        NavigationStack(path: $navigator.path) {
            ScreensCatalog(system: system)
                .routeDestinations(system: system)
        }
        .sheet(item: $navigator.sheet) { route in
            NavigationStack {
                system.screen(for: route)
                    .routeDestinations(system: system)
            }
        }
        .environment(navigator)
    }
}

extension View {
    /// Shows any pushed `Route` as its registered screen.
    public func routeDestinations(system: AppSystem) -> some View {
        navigationDestination(for: Route.self) { route in system.screen(for: route) }
    }
}

extension AppSystem {
    /// The registered screen for `route`, or a placeholder if there is none or its parameters don't fit.
    @MainActor
    public func screen(for route: Route) -> AnyView {
        guard let entry = routes.entry(route.name) else {
            return AnyView(
                ContentUnavailableView("Not available yet", systemImage: "hammer", description: Text(route.name)))
        }
        do {
            return try entry.screen(route, self)
        } catch {
            reportError(error)
            return AnyView(
                ContentUnavailableView("Invalid link", systemImage: "link", description: Text(String(describing: error))))
        }
    }
}

/// Every registered screen. Screens that need parameters are listed, but can only be reached through
/// other screens.
struct ScreensCatalog: View {
    let system: AppSystem

    var body: some View {
        List {
            let entries = system.routes.all
            if entries.isEmpty {
                ContentUnavailableView("No screens yet", systemImage: "rectangle.dashed",
                                       description: Text("Screens appear here as their slices are built."))
            }
            ForEach(entries, id: \.name) { entry in
                if entry.parameters.isEmpty {
                    NavigationLink(entry.title, value: Route(entry.name))
                } else {
                    LabeledContent(entry.title, value: entry.parameters.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Screens")
    }
}
#endif
