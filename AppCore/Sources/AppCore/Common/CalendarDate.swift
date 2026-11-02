import Foundation

/// A day in the calendar, without a time or a time zone: the board's `Date` type.
///
/// Not a `Foundation.Date`, which is a point in time and shows as another day when the device's time
/// zone changes. Encoded as `"yyyy-MM-dd"`.
public struct CalendarDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// `nil` if there is no such day (`2026-02-30`).
    public init?(year: Int, month: Int, day: Int) {
        let components = DateComponents(year: year, month: month, day: day)
        guard (1...9999).contains(year), components.isValidDate(in: Self.gregorian) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `"yyyy-MM-dd"`. `nil` for anything else.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            parts.allSatisfy({ $0.allSatisfy(\.isASCII) }),
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The day `date` falls on in `timeZone`, by default the device's.
    public init(_ date: Date, in timeZone: TimeZone = .current) {
        var calendar = Self.gregorian
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year!
        self.month = components.month!
        self.day = components.day!
    }

    /// Today in `timeZone`, by default the device's.
    public static func today(in timeZone: TimeZone = .current) -> CalendarDate {
        CalendarDate(Date(), in: timeZone)
    }

    /// The first moment of this day in `timeZone`, by default the device's, e.g. for a `DatePicker`.
    public func startOfDay(in timeZone: TimeZone = .current) -> Date {
        var calendar = Self.gregorian
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = CalendarDate(string) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Expected a date as yyyy-MM-dd, got \(string)")
        }
        self = date
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    private static let gregorian = Calendar(identifier: .gregorian)
}
