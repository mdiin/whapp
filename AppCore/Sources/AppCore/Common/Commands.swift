import Foundation

// MARK: - Errors a command can end in

/// A business rule said no. `message` is shown to the user as it is, so write it for them.
public struct CommandRejected: Error, Equatable, Sendable, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

/// The payload didn't decode into the command: fields that are missing or have the wrong type.
/// The counterpart of a coercion error in a web form.
public struct CommandInputError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Messages per field name. A problem not tied to a field is under `""`.
    public let fieldErrors: [String: [String]]

    public init(fieldErrors: [String: [String]]) { self.fieldErrors = fieldErrors }

    init(_ error: DecodingError) {
        func field(_ path: [any CodingKey]) -> String { path.first?.stringValue ?? "" }
        switch error {
        case .keyNotFound(let key, let context):
            fieldErrors = [field(context.codingPath + [key]): ["is required"]]
        case .valueNotFound(_, let context):
            fieldErrors = [field(context.codingPath): ["is required"]]
        case .typeMismatch(_, let context), .dataCorrupted(let context):
            fieldErrors = [field(context.codingPath): ["is not valid"]]
        @unknown default:
            fieldErrors = ["": ["is not valid"]]
        }
    }

    public var description: String {
        fieldErrors.sorted { $0.key < $1.key }
            .map { "\($0.key.isEmpty ? "input" : $0.key) \($0.value.joined(separator: ", "))" }
            .joined(separator: "; ")
    }
}

/// No slice has registered a command by this name (yet). Screens disable the form instead of sending.
public struct CommandNotRegistered: Error, Equatable, Sendable, CustomStringConvertible {
    public let name: String
    public var description: String { "No command named \(name) is registered" }
}

/// A command failed for a reason that isn't the user's: a bug, a failed append condition, the database.
/// It has been reported (`AppSystem.reportError`) and the user sees a general message.
public struct CommandFailed: Error, Sendable, CustomStringConvertible {
    public let name: String
    public let underlying: any Error
    public var description: String { "Command \(name) failed: \(underlying)" }
}

/// What a form shows after a command failed: messages per field, and general ones.
public struct CommandErrors: Equatable, Sendable {
    public var fields: [String: [String]]
    public var general: [String]

    public static let none = CommandErrors(fields: [:], general: [])

    public init(fields: [String: [String]] = [:], general: [String] = []) {
        self.fields = fields
        self.general = general
    }

    /// The errors to show for `error`, as thrown by `AppSystem.send(_:_:)`.
    public init(_ error: any Error) {
        switch error {
        case let rejected as CommandRejected:
            self.init(general: [rejected.message])
        case let input as CommandInputError:
            var fields = input.fieldErrors
            let general = fields.removeValue(forKey: "") ?? []
            self.init(fields: fields, general: general)
        case is CommandNotRegistered:
            self.init(general: ["This action is not available yet."])
        default:
            self.init(general: ["Something went wrong. Please try again."])
        }
    }

    public var isEmpty: Bool { fields.isEmpty && general.isEmpty }

    /// The messages for one field, by its name on the board.
    public subscript(field: String) -> [String] { fields[field] ?? [] }
}

// MARK: - Decoding payloads

/// Decodes a `CommandPayload` (or route parameters) into a slice's own `Decodable` type.
public enum PayloadDecoder {
    /// Throws `CommandInputError` naming the fields that don't fit.
    public static func decode<T: Decodable>(_ type: T.Type, from payload: [String: FieldValue]) throws -> T {
        let data = try JSONEncoder().encode(payload)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw CommandInputError(error)
        }
    }
}

// MARK: - Registry

/// The commands slices have registered, by name (`{context}/{slice}`).
public struct CommandRegistry: Sendable {
    struct Handler: Sendable {
        let run: @Sendable (CommandPayload, AppSystem) async throws -> Void
    }

    let handlers: [String: Handler]

    public func isRegistered(_ name: String) -> Bool { handlers[name] != nil }

    public var names: [String] { handlers.keys.sorted() }

    func send(_ name: String, _ payload: CommandPayload, system: AppSystem) async throws {
        guard let handler = handlers[name] else { throw CommandNotRegistered(name: name) }
        do {
            try await handler.run(payload, system)
        } catch let error as CommandRejected {
            throw error
        } catch let error as CommandInputError {
            throw error
        } catch {
            if !(error is CancellationError) { system.reportError(error) }
            throw CommandFailed(name: name, underlying: error)
        }
    }
}
