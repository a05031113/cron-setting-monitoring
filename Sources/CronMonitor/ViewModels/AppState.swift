import SwiftUI

/// Central observable state for the CronMonitor app.
///
/// Manages the lifecycle of cron jobs and their execution records,
/// keeps the system crontab in sync, and exposes failure status for the menu bar icon.
///
/// All operations run synchronously on `@MainActor` (DataStore is not Sendable).
@MainActor
final class AppState: ObservableObject {
    @Published var jobs: [CronJob] = []
    @Published var executions: [UUID: [ExecutionRecord]] = [:]
    @Published var hasFailures: Bool = false

    let dataStore: DataStore
    let crontabManager: CrontabManager

    private var pollingTimer: Timer?
    private var previousFailureIDs: Set<UUID> = []

    init(dataStore: DataStore = DataStore(), crontabManager: CrontabManager = CrontabManager()) {
        self.dataStore = dataStore
        self.crontabManager = crontabManager
    }

    // MARK: - Public API

    /// Load all jobs and their execution records from the data store.
    func loadAll() {
        do {
            jobs = try dataStore.loadJobs()
        } catch {
            jobs = []
        }

        var loadedExecutions: [UUID: [ExecutionRecord]] = [:]
        for job in jobs {
            loadedExecutions[job.id] = dataStore.loadExecutions(jobId: job.id)
        }
        executions = loadedExecutions

        updateFailureStatus()
    }

    /// Return the most recent execution record for the given job, if any.
    func lastExecution(for jobId: UUID) -> ExecutionRecord? {
        executions[jobId]?.last
    }

    /// Add a new job: persist to data store, sync to crontab, reload state.
    func addJob(_ job: CronJob) throws {
        try dataStore.saveJob(job)
        try syncToCrontab()
        loadAll()
    }

    /// Update an existing job: persist to data store, sync to crontab, reload state.
    func updateJob(_ job: CronJob) throws {
        try dataStore.saveJob(job)
        try syncToCrontab()
        loadAll()
    }

    /// Delete a job: remove from data store, sync to crontab, reload state.
    func deleteJob(_ job: CronJob) throws {
        try dataStore.deleteJob(id: job.id)
        try syncToCrontab()
        loadAll()
    }

    /// Import jobs from the current system crontab.
    ///
    /// Reads crontab lines, creates a `CronJob` for each, saves them to the data store,
    /// then reloads all state.
    func importFromCrontab() throws {
        let lines = try crontabManager.readCrontab()

        for line in lines {
            let scriptName = URL(fileURLWithPath: line.scriptPath).lastPathComponent
            let job = CronJob(
                name: scriptName,
                cronExpression: line.expression.toString(),
                scriptPath: line.scriptPath,
                logPath: line.logPath,
                isEnabled: true
            )
            try dataStore.saveJob(job)
        }

        loadAll()
    }

    // MARK: - Polling

    /// Start polling for new execution records at the given interval.
    func startPolling(interval: TimeInterval = 30) {
        stopPolling()

        // Snapshot current failure IDs so we only notify on truly new failures.
        previousFailureIDs = currentFailureIDs()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForNewExecutions()
            }
        }
    }

    /// Stop the polling timer.
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    /// Reload execution data and send notifications for any newly detected failures.
    private func checkForNewExecutions() {
        let oldFailureIDs = previousFailureIDs

        loadAll()

        let newFailureIDs = currentFailureIDs()
        let brandNewFailures = newFailureIDs.subtracting(oldFailureIDs)

        for failureID in brandNewFailures {
            // Find the execution record and its job to send a notification.
            for (jobId, records) in executions {
                if let record = records.first(where: { $0.id == failureID }),
                   let job = jobs.first(where: { $0.id == jobId }) {
                    NotificationManager.shared.sendFailureNotification(
                        jobName: job.name,
                        exitCode: record.exitCode
                    )
                }
            }
        }

        previousFailureIDs = newFailureIDs
    }

    /// Collect IDs of all execution records that represent failures.
    private func currentFailureIDs() -> Set<UUID> {
        var ids = Set<UUID>()
        for (_, records) in executions {
            for record in records where !record.isSuccess {
                ids.insert(record.id)
            }
        }
        return ids
    }

    // MARK: - Private Helpers

    /// Write all enabled jobs to the system crontab.
    ///
    /// For now this writes jobs directly without a wrapper script
    /// (wrapper integration comes in a later task).
    private func syncToCrontab() throws {
        // Read the latest jobs from data store (includes any just-saved changes
        // that haven't been loaded into `self.jobs` yet).
        let currentJobs: [CronJob]
        do {
            currentJobs = try dataStore.loadJobs()
        } catch {
            currentJobs = jobs
        }

        let lines: [CrontabLine] = currentJobs.filter(\.isEnabled).compactMap { job in
            guard let expression = try? CronExpression.parse(job.cronExpression) else {
                return nil
            }
            return CrontabLine(expression: expression, command: job.scriptPath)
        }

        try crontabManager.writeCrontab(lines: lines)
    }

    /// Update `hasFailures` based on whether any job's most recent execution failed.
    private func updateFailureStatus() {
        hasFailures = jobs.contains { job in
            guard let last = lastExecution(for: job.id) else {
                return false
            }
            return !last.isSuccess
        }
    }
}
