import XCTest
@testable import CronMonitor

final class DataStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: DataStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CronMonitorTests-\(UUID().uuidString)")
        store = DataStore(baseDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Empty State

    func testLoadJobsEmptyStateReturnsEmptyArray() throws {
        let jobs = try store.loadJobs()
        XCTAssertEqual(jobs, [])
    }

    func testLoadExecutionsEmptyStateReturnsEmptyArray() {
        let records = store.loadExecutions(jobId: UUID())
        XCTAssertEqual(records, [])
    }

    // MARK: - Save and Load Jobs

    func testSaveAndLoadJob() throws {
        let job = CronJob(name: "Test Job", cronExpression: "0 9 * * *", scriptPath: "/usr/local/bin/test.sh")
        try store.saveJob(job)

        let loaded = try store.loadJobs()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, job.id)
        XCTAssertEqual(loaded[0].name, "Test Job")
        XCTAssertEqual(loaded[0].cronExpression, "0 9 * * *")
        XCTAssertEqual(loaded[0].scriptPath, "/usr/local/bin/test.sh")
        XCTAssertEqual(loaded[0].isEnabled, true)
        XCTAssertNil(loaded[0].logPath)
        XCTAssertNil(loaded[0].groupId)
    }

    func testSaveMultipleJobs() throws {
        let job1 = CronJob(name: "Job 1", cronExpression: "0 9 * * *", scriptPath: "/bin/a.sh")
        let job2 = CronJob(name: "Job 2", cronExpression: "*/5 * * * *", scriptPath: "/bin/b.sh", logPath: "/tmp/b.log")
        try store.saveJob(job1)
        try store.saveJob(job2)

        let loaded = try store.loadJobs()
        XCTAssertEqual(loaded.count, 2)
        let ids = Set(loaded.map(\.id))
        XCTAssertTrue(ids.contains(job1.id))
        XCTAssertTrue(ids.contains(job2.id))
    }

    // MARK: - Update Existing Job

    func testUpdateExistingJob() throws {
        var job = CronJob(name: "Original", cronExpression: "0 9 * * *", scriptPath: "/bin/test.sh")
        try store.saveJob(job)

        job.name = "Updated"
        job.isEnabled = false
        try store.saveJob(job)

        let loaded = try store.loadJobs()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, job.id)
        XCTAssertEqual(loaded[0].name, "Updated")
        XCTAssertEqual(loaded[0].isEnabled, false)
    }

    // MARK: - Delete Job

    func testDeleteJob() throws {
        let job1 = CronJob(name: "Job 1", cronExpression: "0 9 * * *", scriptPath: "/bin/a.sh")
        let job2 = CronJob(name: "Job 2", cronExpression: "*/5 * * * *", scriptPath: "/bin/b.sh")
        try store.saveJob(job1)
        try store.saveJob(job2)

        try store.deleteJob(id: job1.id)

        let loaded = try store.loadJobs()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, job2.id)
    }

    func testDeleteNonExistentJobDoesNotThrow() throws {
        XCTAssertNoThrow(try store.deleteJob(id: UUID()))
    }

    // MARK: - Execution Records

    func testSaveAndLoadExecutionRecords() throws {
        let jobId = UUID()
        let now = Date()
        let record = ExecutionRecord(
            id: UUID(),
            jobId: jobId,
            startedAt: now,
            finishedAt: now.addingTimeInterval(5),
            exitCode: 0,
            stdout: "OK",
            stderr: nil
        )
        try store.saveExecution(record)

        let loaded = store.loadExecutions(jobId: jobId)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, record.id)
        XCTAssertEqual(loaded[0].jobId, jobId)
        XCTAssertEqual(loaded[0].exitCode, 0)
        XCTAssertEqual(loaded[0].stdout, "OK")
        XCTAssertNil(loaded[0].stderr)
        XCTAssertTrue(loaded[0].isSuccess)
        XCTAssertEqual(loaded[0].duration, 5, accuracy: 0.01)
    }

    func testSaveMultipleExecutionRecords() throws {
        let jobId = UUID()
        let now = Date()

        for i in 0..<5 {
            let record = ExecutionRecord(
                id: UUID(),
                jobId: jobId,
                startedAt: now.addingTimeInterval(Double(i * 10)),
                finishedAt: now.addingTimeInterval(Double(i * 10 + 2)),
                exitCode: i == 3 ? 1 : 0,
                stdout: "run \(i)",
                stderr: i == 3 ? "error" : nil
            )
            try store.saveExecution(record)
        }

        let loaded = store.loadExecutions(jobId: jobId)
        XCTAssertEqual(loaded.count, 5)
    }

    func testLoadExecutionsWithLimit() throws {
        let jobId = UUID()
        let now = Date()

        for i in 0..<10 {
            let record = ExecutionRecord(
                id: UUID(),
                jobId: jobId,
                startedAt: now.addingTimeInterval(Double(i * 10)),
                finishedAt: now.addingTimeInterval(Double(i * 10 + 2)),
                exitCode: 0,
                stdout: nil,
                stderr: nil
            )
            try store.saveExecution(record)
        }

        let limited = store.loadExecutions(jobId: jobId, limit: 3)
        XCTAssertEqual(limited.count, 3)
    }

    func testExecutionRecordsIsolatedPerJob() throws {
        let jobId1 = UUID()
        let jobId2 = UUID()
        let now = Date()

        let record1 = ExecutionRecord(
            id: UUID(), jobId: jobId1,
            startedAt: now, finishedAt: now.addingTimeInterval(1),
            exitCode: 0, stdout: nil, stderr: nil
        )
        let record2 = ExecutionRecord(
            id: UUID(), jobId: jobId2,
            startedAt: now, finishedAt: now.addingTimeInterval(1),
            exitCode: 0, stdout: nil, stderr: nil
        )
        try store.saveExecution(record1)
        try store.saveExecution(record2)

        XCTAssertEqual(store.loadExecutions(jobId: jobId1).count, 1)
        XCTAssertEqual(store.loadExecutions(jobId: jobId2).count, 1)
    }

    // MARK: - CronJob Model

    func testCronJobParsedExpression() {
        let job = CronJob(name: "Test", cronExpression: "0 9 * * *", scriptPath: "/bin/test.sh")
        XCTAssertNotNil(job.parsedExpression)
        XCTAssertEqual(job.parsedExpression?.hour, "9")
        XCTAssertEqual(job.parsedExpression?.minute, "0")
    }

    func testCronJobParsedExpressionInvalid() {
        let job = CronJob(name: "Test", cronExpression: "invalid", scriptPath: "/bin/test.sh")
        XCTAssertNil(job.parsedExpression)
    }

    func testCronJobDefaults() {
        let job = CronJob(name: "Test", cronExpression: "0 9 * * *", scriptPath: "/bin/test.sh")
        XCTAssertTrue(job.isEnabled)
        XCTAssertNil(job.logPath)
        XCTAssertNil(job.groupId)
    }

    // MARK: - ExecutionRecord Computed Properties

    func testExecutionRecordIsSuccess() {
        let now = Date()
        let success = ExecutionRecord(
            id: UUID(), jobId: UUID(),
            startedAt: now, finishedAt: now.addingTimeInterval(1),
            exitCode: 0, stdout: nil, stderr: nil
        )
        let failure = ExecutionRecord(
            id: UUID(), jobId: UUID(),
            startedAt: now, finishedAt: now.addingTimeInterval(1),
            exitCode: 1, stdout: nil, stderr: "error"
        )
        XCTAssertTrue(success.isSuccess)
        XCTAssertFalse(failure.isSuccess)
    }

    func testExecutionRecordDuration() {
        let now = Date()
        let record = ExecutionRecord(
            id: UUID(), jobId: UUID(),
            startedAt: now, finishedAt: now.addingTimeInterval(42.5),
            exitCode: 0, stdout: nil, stderr: nil
        )
        XCTAssertEqual(record.duration, 42.5, accuracy: 0.01)
    }
}
