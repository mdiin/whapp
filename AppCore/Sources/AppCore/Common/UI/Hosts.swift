#if canImport(SwiftUI)
import Ledjer
import SwiftUI

/// Hosts a screen the way `RootView` does (in a navigation stack, with a `Navigator`), for previews
/// and snapshot tests.
public struct ScreenHost<Content: View>: View {
    private let system: AppSystem
    private let content: Content
    @State private var navigator = Navigator()

    public init(system: AppSystem, @ViewBuilder content: () -> Content) {
        self.system = system
        self.content = content()
    }

    public var body: some View {
        NavigationStack(path: $navigator.path) {
            content.routeDestinations(system: system)
        }
        .environment(navigator)
    }
}

/// A preview of a screen on an in-memory system with `given` events:
///
/// ```swift
/// #Preview {
///     PreviewHost(given: [CartCreated(cartId: id)]) { system in
///         CartItemsScreen(system: system, cartId: id)
///     }
/// }
/// ```
public struct PreviewHost<Content: View>: View {
    private let given: [any Event]
    private let content: (AppSystem) -> Content
    @State private var system: AppSystem?
    @State private var failure: String?

    public init(given: [any Event] = [], @ViewBuilder content: @escaping (AppSystem) -> Content) {
        self.given = given
        self.content = content
    }

    public var body: some View {
        Group {
            if let system {
                ScreenHost(system: system) { content(system) }
            } else if let failure {
                Text(failure)
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                let system = try await AppSystem.inMemory(given: given)
                system.activity.set(true)
                self.system = system
            } catch {
                failure = String(describing: error)
            }
        }
    }
}

/// A link to another slice's screen, by name. Disabled while that screen isn't registered.
public struct RouteLink<Label: View>: View {
    private let route: Route
    private let system: AppSystem
    private let label: Label

    public init(_ route: Route, system: AppSystem, @ViewBuilder label: () -> Label) {
        self.route = route
        self.system = system
        self.label = label()
    }

    public var body: some View {
        NavigationLink(value: route) { label }
            .disabled(!system.routes.isRegistered(route.name))
    }
}

/// Error messages of a form, unstyled: style them as the project's design system says.
public struct ErrorMessages: View {
    private let messages: [String]

    public init(_ messages: [String]) {
        self.messages = messages
    }

    public var body: some View {
        ForEach(messages, id: \.self) { message in
            Text(message)
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }
}
#endif
