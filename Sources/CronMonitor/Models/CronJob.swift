import Foundation

/// A cron job definition with metadata for monitoring.
struct CronJob: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var cronExpression: String
    var scriptPath: String
    var logPath: String?
    var isEnabled: Bool
    var groupId: UUID?
    let createdAt: Date

    /// Convenience initializer with sensible defaults.
    init(
        id: UUID = UUID(),
        name: String,
        cronExpression: String,
        scriptPath: String,
        logPath: String? = nil,
        isEnabled: Bool = true,
        groupId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.cronExpression = cronExpression
        self.scriptPath = scriptPath
        self.logPath = logPath
        self.isEnabled = isEnabled
        self.groupId = groupId
        self.createdAt = createdAt
    }

    /// Attempt to parse the `cronExpression` string into a `CronExpression`.
    /// Returns `nil` if the expression is invalid.
    var parsedExpression: CronExpression? {
        try? CronExpression.parse(cronExpression)
    }
}
