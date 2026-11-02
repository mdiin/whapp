import Foundation

/// A value of a board field, as screens pass it to commands (`CommandPayload`) and to screens (`Route`).
///
/// Slices never depend on each other's Swift types, so what crosses from one slice to another is a
/// dictionary of these, keyed by the board's field names. The receiving slice decodes it into its own
/// typed struct (see `PayloadDecoder`).
public enum FieldValue: Hashable, Sendable {
    case null
    case string(String)
    case int(Int)
    case double(Double)
    case decimal(Decimal)
    case bool(Bool)
    case uuid(UUID)
    case date(CalendarDate)
    case dateTime(Date)
    case list([FieldValue])
    case object([String: FieldValue])
}

extension FieldValue {
    /// Wraps an optional: `nil` becomes `.null`.
    public static func optional(_ value: FieldValue?) -> FieldValue { value ?? .null }
}

extension FieldValue: Encodable {
    /// Encoded the way `JSONDecoder` decodes the matching Swift type, so a payload decodes into a
    /// `Codable` command (`Date` with the default `deferredToDate` strategy on both sides).
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .decimal(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .uuid(let value): try container.encode(value)
        case .date(let value): try container.encode(value)
        case .dateTime(let value): try container.encode(value)
        case .list(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension FieldValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByNilLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(nilLiteral: ()) { self = .null }
    public init(arrayLiteral elements: FieldValue...) { self = .list(elements) }
    public init(dictionaryLiteral elements: (String, FieldValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

/// The input of a command, keyed by the command's field names on the board.
public typealias CommandPayload = [String: FieldValue]
