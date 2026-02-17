import Foundation

/// A record of a single cron job execution.
struct ExecutionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let jobId: UUID
    let startedAt: Date
    let finishedAt: Date
    let exitCode: Int
    let stdout: String?
    let stderr: String?

    /// Whether the execution completed successfully (exit code 0).
    var isSuccess: Bool { exitCode == 0 }

    /// Duration of the execution in seconds.
    var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
}
