import Foundation

typealias JSON = [String: Any]

/// Chová se jako org.json `optString`: chybějící klíč / null → "", číslo → jeho textová podoba.
func jsonString(_ value: Any?) -> String {
    guard let value, !(value is NSNull) else { return "" }
    if let s = value as? String { return s }
    if let n = value as? NSNumber {
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
        return n.stringValue
    }
    return ""
}

extension Dictionary where Key == String, Value == Any {
    func str(_ key: String) -> String { jsonString(self[key]) }

    func int(_ key: String, default fallback: Int = 0) -> Int {
        guard let v = self[key], !(v is NSNull) else { return fallback }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String, let i = Int(s.trimmed) { return i }
        return fallback
    }

    func obj(_ key: String) -> JSON? { self[key] as? JSON }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var moneyOrNil: Double? { Double(trimmed.replacingOccurrences(of: ",", with: ".")) }
    var withoutTrailingSlash: String {
        var s = self
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
    var capitalizedFirst: String { prefix(1).uppercased() + String(dropFirst()) }
}
