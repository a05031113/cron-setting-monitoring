import Foundation

/// Errors thrown during cron expression or crontab line parsing.
enum CronParseError: Error, Sendable {
    case invalidFormat(String)
    case emptyInput
    case commentLine
}

/// Represents a parsed cron expression with five standard fields.
struct CronExpression: Codable, Equatable, Sendable {
    let minute: String
    let hour: String
    let dayOfMonth: String
    let month: String
    let dayOfWeek: String

    /// Parse a raw cron expression string (e.g. "50 8 * * 1-7") into a CronExpression.
    /// Throws `CronParseError` if the input has fewer than 5 fields.
    static func parse(_ raw: String) throws -> CronExpression {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw CronParseError.emptyInput
        }

        let fields = trimmed.split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard fields.count >= 5 else {
            throw CronParseError.invalidFormat(
                "Expected at least 5 fields, got \(fields.count)"
            )
        }

        return CronExpression(
            minute: fields[0],
            hour: fields[1],
            dayOfMonth: fields[2],
            month: fields[3],
            dayOfWeek: fields[4]
        )
    }

    /// Reconstruct the cron expression string.
    func toString() -> String {
        "\(minute) \(hour) \(dayOfMonth) \(month) \(dayOfWeek)"
    }

    /// A human-readable description of the cron schedule.
    var humanReadable: String {
        // Every minute
        if minute == "*" && hour == "*" && dayOfMonth == "*" && month == "*" && dayOfWeek == "*" {
            return "Every minute"
        }

        // Every N minutes (*/N pattern)
        if minute.hasPrefix("*/"), hour == "*", dayOfMonth == "*", month == "*", dayOfWeek == "*" {
            let interval = String(minute.dropFirst(2))
            return "Every \(interval) minutes"
        }

        // Every hour (minute is fixed, hour is *)
        if minute != "*", hour == "*", dayOfMonth == "*", month == "*", dayOfWeek == "*" {
            return "Every hour"
        }

        // Fixed hour and minute
        if minute != "*", hour != "*" {
            let timeStr = formatTime(hour: hour, minute: minute)

            // Specific day of month
            if dayOfMonth != "*", month == "*", dayOfWeek == "*" {
                return "Day \(dayOfMonth) at \(timeStr)"
            }

            // Specific day(s) of week
            if dayOfMonth == "*", month == "*", dayOfWeek != "*" {
                let dayStr = dayOfWeekDescription(dayOfWeek)
                return "\(dayStr) at \(timeStr)"
            }

            // Every day (all wildcards except hour/minute)
            if dayOfMonth == "*", month == "*", dayOfWeek == "*" {
                return "Every day at \(timeStr)"
            }
        }

        // Fallback
        return toString()
    }

    /// Calculate the next run time after the given date.
    /// Supports simple hour+minute patterns (specific hour and minute, day/month/week all wildcard).
    func nextRun(after date: Date) -> Date? {
        guard minute != "*", hour != "*",
              let h = Int(hour), let m = Int(minute) else {
            return nil
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Build candidate for same day
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = h
        components.minute = m
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")

        guard let candidate = calendar.date(from: components) else {
            return nil
        }

        if candidate > date {
            return candidate
        }

        // Next day
        return calendar.date(byAdding: .day, value: 1, to: candidate)
    }

    // MARK: - Private helpers

    private func formatTime(hour: String, minute: String) -> String {
        let h = Int(hour) ?? 0
        let m = Int(minute) ?? 0
        return String(format: "%02d:%02d", h, m)
    }

    private static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private func dayOfWeekDescription(_ field: String) -> String {
        // Range: "1-7" -> "Mon-Sun"
        if let dashIndex = field.firstIndex(of: "-") {
            let startStr = String(field[field.startIndex..<dashIndex])
            let endStr = String(field[field.index(after: dashIndex)...])
            if let start = Int(startStr), let end = Int(endStr),
               start >= 0, start <= 7, end >= 0, end <= 7 {
                return "\(Self.dayNames[start])-\(Self.dayNames[end])"
            }
        }

        // Single day: "1" -> "Mon"
        if let day = Int(field), day >= 0, day <= 7 {
            return Self.dayNames[day]
        }

        // Comma-separated or other complex patterns: return as-is
        return field
    }
}
