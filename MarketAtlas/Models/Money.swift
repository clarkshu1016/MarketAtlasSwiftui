import Foundation

enum Money {
    /// "$4.91 T", "$39.48 B", "$512.3 M", "-$0.37 B" — same shape as the server's display strings,
    /// so computed values read consistently next to scraped ones.
    static func short(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        let a = abs(value)
        switch a {
        case 1e12...: return "\(sign)$" + String(format: "%.2f", a / 1e12) + " T"
        case 1e11...: return "\(sign)$" + String(format: "%.1f", a / 1e9) + " B"
        case 1e9...:  return "\(sign)$" + String(format: "%.2f", a / 1e9) + " B"
        case 1e6...:  return "\(sign)$" + String(format: "%.1f", a / 1e6) + " M"
        case 1e3...:  return "\(sign)$" + String(format: "%.1f", a / 1e3) + " K"
        default:      return "\(sign)$" + String(format: "%.0f", a)
        }
    }

    /// "2026-10-10" → "Oct 2026"
    static func monthYear(fromISO iso: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }
}
