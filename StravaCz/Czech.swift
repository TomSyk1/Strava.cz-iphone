import Foundation

/// České formátování a parsování dat (server i UI pracují v pražském čase).
enum Czech {
    static let timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
    static let locale = Locale(identifier: "cs_CZ")

    private static func makeFormatter(_ format: String, posix: Bool) -> DateFormatter {
        let f = DateFormatter()
        f.locale = posix ? Locale(identifier: "en_US_POSIX") : Czech.locale
        f.timeZone = Czech.timeZone
        f.dateFormat = format
        return f
    }

    // Parsování
    private static let keyFormatter = Czech.makeFormatter("yyyy-MM-dd", posix: true)
    private static let dateParsers: [DateFormatter] = ["dd.MM.yyyy", "dd-MM.yyyy", "d.M.yyyy", "d-M-yyyy"]
        .map { Czech.makeFormatter($0, posix: true) }
    private static let dateTimeParsers: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "dd.MM.yyyy HH:mm", "d.M.yyyy H:mm", "dd.MM.yyyy'T'HH:mm:ss",
    ].map { Czech.makeFormatter($0, posix: true) }

    /// "05.10.2026" → "2026-10-05"
    static func parseDateKey(_ value: String) -> String? {
        let v = value.trimmed
        for parser in dateParsers {
            if let d = parser.date(from: v) { return keyFormatter.string(from: d) }
        }
        return nil
    }

    static func date(fromKey key: String) -> Date? { keyFormatter.date(from: key) }

    static func parseDateTime(_ value: String) -> Date? {
        let v = value.trimmed
        if v.isEmpty { return nil }
        for parser in dateTimeParsers {
            if let d = parser.date(from: v) { return d }
        }
        return nil
    }

    // Zobrazení
    private static let longDateFormatter = Czech.makeFormatter("EEEE d. MMMM yyyy", posix: false)
    private static let chipFormatter = Czech.makeFormatter("EEE d. M.", posix: false)
    private static let deadlineFormatter = Czech.makeFormatter("d. M. HH:mm", posix: false)

    static func longDate(_ d: Date) -> String { longDateFormatter.string(from: d).capitalizedFirst }
    static func chipDate(_ d: Date) -> String { chipFormatter.string(from: d).capitalizedFirst }
    static func deadline(_ d: Date) -> String { deadlineFormatter.string(from: d) }
    static func price(_ v: Double) -> String { String(format: "%.2f", locale: locale, v) }
}
