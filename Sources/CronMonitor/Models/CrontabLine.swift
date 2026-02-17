import Foundation

/// Represents a parsed crontab line: a cron expression plus the command to run.
struct CrontabLine: Codable, Equatable, Sendable {
    let expression: CronExpression
    let command: String

    /// Parse a full crontab line (e.g. "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1").
    /// Throws on comment lines (starting with #), empty lines, or lines with too few fields.
    static func parse(_ line: String) throws -> CrontabLine {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            throw CronParseError.emptyInput
        }

        guard !trimmed.hasPrefix("#") else {
            throw CronParseError.commentLine
        }

        let fields = trimmed.split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard fields.count >= 6 else {
            throw CronParseError.invalidFormat(
                "Crontab line requires at least 6 fields (5 cron + command), got \(fields.count)"
            )
        }

        let cronRaw = fields[0...4].joined(separator: " ")
        let expr = try CronExpression.parse(cronRaw)

        // Reconstruct the command portion preserving original spacing.
        // Find the start index of the 6th token in the trimmed string.
        let commandStr = extractCommand(from: trimmed)

        return CrontabLine(expression: expr, command: commandStr)
    }

    /// The first token of the command (typically the script/binary path).
    var scriptPath: String {
        let parts = command.split(whereSeparator: { $0.isWhitespace })
        return parts.isEmpty ? command : String(parts[0])
    }

    /// Extract the log file path from output redirection (>> or >) in the command, if present.
    var logPath: String? {
        // Look for ">>" first, then ">"
        let tokens = command.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        for (index, token) in tokens.enumerated() {
            if (token == ">>" || token == ">"), index + 1 < tokens.count {
                return tokens[index + 1]
            }
        }
        return nil
    }

    /// Reconstruct the full crontab line.
    func toString() -> String {
        "\(expression.toString()) \(command)"
    }

    // MARK: - Private helpers

    /// Extract the command portion from a trimmed crontab line by skipping 5 cron fields.
    private static func extractCommand(from trimmed: String) -> String {
        var index = trimmed.startIndex
        var fieldCount = 0
        var inWhitespace = false

        while index < trimmed.endIndex && fieldCount < 5 {
            if trimmed[index].isWhitespace {
                if !inWhitespace {
                    fieldCount += 1
                    inWhitespace = true
                }
            } else {
                inWhitespace = false
            }
            if fieldCount < 5 {
                index = trimmed.index(after: index)
            }
        }

        // Skip remaining whitespace between field 5 and command
        while index < trimmed.endIndex && trimmed[index].isWhitespace {
            index = trimmed.index(after: index)
        }

        return String(trimmed[index...])
    }
}
