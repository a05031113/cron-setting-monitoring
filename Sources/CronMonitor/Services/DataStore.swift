import Foundation

/// JSON file-based persistence for cron jobs and execution records.
///
/// Data layout:
/// - `baseDir/jobs.json` — array of `CronJob`
/// - `baseDir/executions/{jobId}.json` — array of `ExecutionRecord` per job
///
/// Not `Sendable`; intended for use on `@MainActor` only.
final class DataStore {
    private let baseDir: URL
    private let executionsDir: URL
    private let jobsFileURL: URL

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Initialize the data store.
    /// - Parameter baseDir: Root directory for data files. Defaults to `~/.cronmonitor/`.
    init(baseDir: URL? = nil) {
        let dir = baseDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cronmonitor")
        self.baseDir = dir
        self.executionsDir = dir.appendingPathComponent("executions")
        self.jobsFileURL = dir.appendingPathComponent("jobs.json")

        // Create directories if needed.
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: executionsDir, withIntermediateDirectories: true)
    }

    // MARK: - Jobs

    /// Load all saved jobs. Returns an empty array if no jobs file exists.
    func loadJobs() throws -> [CronJob] {
        guard FileManager.default.fileExists(atPath: jobsFileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: jobsFileURL)
        return try decoder.decode([CronJob].self, from: data)
    }

    /// Save a job. If a job with the same `id` exists, it is replaced.
    func saveJob(_ job: CronJob) throws {
        var jobs = try loadJobs()
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        } else {
            jobs.append(job)
        }
        let data = try encoder.encode(jobs)
        try data.write(to: jobsFileURL, options: .atomic)
    }

    /// Delete a job by id. Does nothing if the job does not exist.
    func deleteJob(id: UUID) throws {
        var jobs = try loadJobs()
        jobs.removeAll { $0.id == id }
        let data = try encoder.encode(jobs)
        try data.write(to: jobsFileURL, options: .atomic)
    }

    // MARK: - Execution Records

    /// Save an execution record, appending it to the per-job file.
    func saveExecution(_ record: ExecutionRecord) throws {
        let fileURL = executionFileURL(for: record.jobId)
        var records = loadAllExecutions(from: fileURL)
        records.append(record)
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Load execution records for a job, returning the most recent up to `limit`.
    /// Returns an empty array if no records exist.
    func loadExecutions(jobId: UUID, limit: Int = 50) -> [ExecutionRecord] {
        let fileURL = executionFileURL(for: jobId)
        let all = loadAllExecutions(from: fileURL)
        if all.count <= limit {
            return all
        }
        return Array(all.suffix(limit))
    }

    // MARK: - Private Helpers

    private func executionFileURL(for jobId: UUID) -> URL {
        executionsDir.appendingPathComponent("\(jobId.uuidString).json")
    }

    private func loadAllExecutions(from fileURL: URL) -> [ExecutionRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let records = try? decoder.decode([ExecutionRecord].self, from: data) else {
            return []
        }
        return records
    }
}
