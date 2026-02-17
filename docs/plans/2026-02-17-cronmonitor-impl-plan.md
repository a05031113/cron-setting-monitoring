# CronMonitor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS Menu Bar app that visually manages and monitors crontab jobs with execution history tracking.

**Architecture:** SwiftUI Menu Bar app using `MenuBarExtra`. Crontab interaction via `Process`. Execution monitoring via wrapper shell script. Data persistence via JSON files (`~/.cronmonitor/`). No external database dependency for v1.

**Tech Stack:** Swift 5.8+, SwiftUI, AppKit (NSOpenPanel), SPM executable, UserNotifications

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/CronMonitor/CronMonitorApp.swift`
- Create: `Sources/CronMonitor/Models/CronJob.swift`
- Create: `Tests/CronMonitorTests/CronParserTests.swift`

**Step 1: Initialize SPM package**

```bash
cd /Users/yanghaoyu/Documents/cron-setting-monitoring
swift package init --type executable --name CronMonitor
```

**Step 2: Configure Package.swift**

Update `Package.swift` to target macOS 14+, set up test target:

```swift
// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "CronMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CronMonitor",
            path: "Sources/CronMonitor"
        ),
        .testTarget(
            name: "CronMonitorTests",
            dependencies: ["CronMonitor"],
            path: "Tests/CronMonitorTests"
        ),
    ]
)
```

**Step 3: Create minimal App entry point**

`Sources/CronMonitor/CronMonitorApp.swift`:
```swift
import SwiftUI

@main
struct CronMonitorApp: App {
    var body: some Scene {
        MenuBarExtra("CronMonitor", systemImage: "clock") {
            Text("CronMonitor is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

**Step 4: Build and verify**

```bash
swift build
```
Expected: BUILD SUCCEEDED

**Step 5: Run to verify menu bar icon appears**

```bash
.build/debug/CronMonitor &
```
Expected: Clock icon appears in menu bar. Kill with Ctrl+C after verification.

**Step 6: Commit**

```bash
git init
git add Package.swift Sources/ Tests/
git commit -m "feat: initial project scaffolding with menu bar app shell"
```

---

### Task 2: Cron Expression Parser

**Files:**
- Create: `Sources/CronMonitor/Models/CronExpression.swift`
- Create: `Tests/CronMonitorTests/CronExpressionTests.swift`

**Step 1: Write failing tests for cron parsing**

`Tests/CronMonitorTests/CronExpressionTests.swift`:
```swift
import XCTest
@testable import CronMonitor

final class CronExpressionTests: XCTestCase {

    func testParseSimpleCron() throws {
        let expr = try CronExpression.parse("50 8 * * 1-7")
        XCTAssertEqual(expr.minute, "50")
        XCTAssertEqual(expr.hour, "8")
        XCTAssertEqual(expr.dayOfMonth, "*")
        XCTAssertEqual(expr.month, "*")
        XCTAssertEqual(expr.dayOfWeek, "1-7")
    }

    func testHumanReadableDaily() throws {
        let expr = try CronExpression.parse("0 9 * * *")
        XCTAssertEqual(expr.humanReadable, "Every day at 09:00")
    }

    func testHumanReadableSpecificMinutes() throws {
        let expr = try CronExpression.parse("50 8 * * 1-7")
        XCTAssertEqual(expr.humanReadable, "Mon-Sun at 08:50")
    }

    func testHumanReadableEveryNMinutes() throws {
        let expr = try CronExpression.parse("*/5 * * * *")
        XCTAssertEqual(expr.humanReadable, "Every 5 minutes")
    }

    func testHumanReadableWeekly() throws {
        let expr = try CronExpression.parse("0 9 * * 1")
        XCTAssertEqual(expr.humanReadable, "Mon at 09:00")
    }

    func testInvalidCronThrows() {
        XCTAssertThrowsError(try CronExpression.parse("invalid"))
        XCTAssertThrowsError(try CronExpression.parse("1 2 3"))
    }

    func testBuildFromComponents() {
        let expr = CronExpression(minute: "30", hour: "14", dayOfMonth: "*", month: "*", dayOfWeek: "*")
        XCTAssertEqual(expr.toString(), "30 14 * * *")
    }

    func testNextRunDate() throws {
        let expr = try CronExpression.parse("0 9 * * *")
        let next = expr.nextRun(after: makeDate(2026, 2, 17, 8, 0))
        XCTAssertEqual(calendar.component(.hour, from: next!), 9)
        XCTAssertEqual(calendar.component(.minute, from: next!), 0)
    }

    private let calendar = Calendar.current

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d, hour: h, minute: min).date!
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test --filter CronExpressionTests 2>&1 | tail -20
```
Expected: FAIL - CronExpression not found

**Step 3: Implement CronExpression**

`Sources/CronMonitor/Models/CronExpression.swift`:
```swift
import Foundation

struct CronExpression: Codable, Equatable {
    let minute: String
    let hour: String
    let dayOfMonth: String
    let month: String
    let dayOfWeek: String

    enum ParseError: Error {
        case invalidFormat(String)
    }

    static func parse(_ raw: String) throws -> CronExpression {
        let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard parts.count == 5 else {
            throw ParseError.invalidFormat("Expected 5 fields, got \(parts.count)")
        }
        return CronExpression(
            minute: String(parts[0]),
            hour: String(parts[1]),
            dayOfMonth: String(parts[2]),
            month: String(parts[3]),
            dayOfWeek: String(parts[4])
        )
    }

    func toString() -> String {
        "\(minute) \(hour) \(dayOfMonth) \(month) \(dayOfWeek)"
    }

    var humanReadable: String {
        // Every N minutes
        if minute.hasPrefix("*/"), hour == "*", dayOfMonth == "*", month == "*", dayOfWeek == "*" {
            let interval = minute.dropFirst(2)
            return "Every \(interval) minutes"
        }

        let timeStr = String(format: "%02d:%02d",
                             Int(hour) ?? 0, Int(minute) ?? 0)

        let dayStr = dayOfWeekDescription

        if dayOfMonth == "*" && month == "*" {
            if dayOfWeek == "*" {
                return "Every day at \(timeStr)"
            } else {
                return "\(dayStr) at \(timeStr)"
            }
        }

        return toString()
    }

    private var dayOfWeekDescription: String {
        let map = ["0": "Sun", "1": "Mon", "2": "Tue", "3": "Wed",
                   "4": "Thu", "5": "Fri", "6": "Sat", "7": "Sun"]

        if dayOfWeek == "1-7" || dayOfWeek == "0-6" || dayOfWeek == "*" {
            return "Mon-Sun"
        }
        if let name = map[dayOfWeek] {
            return name
        }
        if dayOfWeek == "1-5" { return "Mon-Fri" }
        if dayOfWeek == "0,6" || dayOfWeek == "6,0" { return "Sat-Sun" }
        return dayOfWeek
    }

    func nextRun(after date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        var candidate = calendar.nextDate(
            after: date,
            matching: DateComponents(
                minute: Int(minute),
                hour: Int(hour)
            ),
            matchingPolicy: .nextTime
        )
        return candidate
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
swift test --filter CronExpressionTests
```
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Sources/CronMonitor/Models/CronExpression.swift Tests/
git commit -m "feat: add cron expression parser with human-readable output"
```

---

### Task 3: Crontab Line Parser

**Files:**
- Create: `Sources/CronMonitor/Models/CrontabLine.swift`
- Create: `Tests/CronMonitorTests/CrontabLineTests.swift`

**Step 1: Write failing tests**

`Tests/CronMonitorTests/CrontabLineTests.swift`:
```swift
import XCTest
@testable import CronMonitor

final class CrontabLineTests: XCTestCase {

    func testParseFullLine() throws {
        let line = "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1"
        let parsed = try CrontabLine.parse(line)

        XCTAssertEqual(parsed.expression.minute, "50")
        XCTAssertEqual(parsed.expression.hour, "8")
        XCTAssertEqual(parsed.command, "/Users/user/script.sh >> /Users/user/log.log 2>&1")
        XCTAssertEqual(parsed.scriptPath, "/Users/user/script.sh")
        XCTAssertEqual(parsed.logPath, "/Users/user/log.log")
    }

    func testParseLineWithoutRedirect() throws {
        let line = "0 9 * * * /usr/local/bin/backup.sh"
        let parsed = try CrontabLine.parse(line)

        XCTAssertEqual(parsed.scriptPath, "/usr/local/bin/backup.sh")
        XCTAssertNil(parsed.logPath)
    }

    func testParseCommentLine() {
        XCTAssertThrowsError(try CrontabLine.parse("# this is a comment"))
    }

    func testParseEmptyLine() {
        XCTAssertThrowsError(try CrontabLine.parse(""))
    }

    func testToString() throws {
        let line = try CrontabLine.parse("50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1")
        XCTAssertEqual(line.toString(), "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1")
    }
}
```

**Step 2: Run tests - expect failure**

```bash
swift test --filter CrontabLineTests 2>&1 | tail -5
```

**Step 3: Implement CrontabLine**

`Sources/CronMonitor/Models/CrontabLine.swift`:
```swift
import Foundation

struct CrontabLine: Codable, Equatable {
    let expression: CronExpression
    let command: String

    enum ParseError: Error {
        case emptyLine
        case commentLine
        case invalidFormat(String)
    }

    static func parse(_ line: String) throws -> CrontabLine {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw ParseError.emptyLine }
        guard !trimmed.hasPrefix("#") else { throw ParseError.commentLine }

        let parts = trimmed.split(separator: " ", maxSplits: 5)
        guard parts.count >= 6 else {
            throw ParseError.invalidFormat("Need at least 6 parts (5 cron fields + command)")
        }

        let cronStr = parts[0..<5].joined(separator: " ")
        let command = String(parts[5])

        let expression = try CronExpression.parse(cronStr)
        return CrontabLine(expression: expression, command: command)
    }

    var scriptPath: String {
        let parts = command.split(separator: " ")
        return String(parts.first ?? "")
    }

    var logPath: String? {
        guard let range = command.range(of: ">>\\s*([^\\s]+)", options: .regularExpression) else {
            return nil
        }
        let match = command[range]
        return match.replacingOccurrences(of: ">>", with: "").trimmingCharacters(in: .whitespaces)
    }

    func toString() -> String {
        "\(expression.toString()) \(command)"
    }
}
```

**Step 4: Run tests**

```bash
swift test --filter CrontabLineTests
```
Expected: All PASS

**Step 5: Commit**

```bash
git add Sources/CronMonitor/Models/CrontabLine.swift Tests/
git commit -m "feat: add crontab line parser with script/log path extraction"
```

---

### Task 4: CronJob Data Model + JSON Persistence

**Files:**
- Create: `Sources/CronMonitor/Models/CronJob.swift`
- Create: `Sources/CronMonitor/Models/ExecutionRecord.swift`
- Create: `Sources/CronMonitor/Services/DataStore.swift`
- Create: `Tests/CronMonitorTests/DataStoreTests.swift`

**Step 1: Write failing tests**

`Tests/CronMonitorTests/DataStoreTests.swift`:
```swift
import XCTest
@testable import CronMonitor

final class DataStoreTests: XCTestCase {
    var store: DataStore!
    var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = DataStore(baseDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveAndLoadJobs() throws {
        let job = CronJob(
            name: "Test Job",
            cronExpression: "0 9 * * *",
            scriptPath: "/usr/local/bin/test.sh",
            logPath: nil,
            isEnabled: true
        )
        try store.saveJob(job)

        let loaded = try store.loadJobs()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Test Job")
        XCTAssertEqual(loaded[0].cronExpression, "0 9 * * *")
    }

    func testDeleteJob() throws {
        let job = CronJob(name: "To Delete", cronExpression: "0 9 * * *",
                          scriptPath: "/bin/test.sh", logPath: nil, isEnabled: true)
        try store.saveJob(job)
        try store.deleteJob(id: job.id)

        let loaded = try store.loadJobs()
        XCTAssertEqual(loaded.count, 0)
    }

    func testSaveAndLoadExecutionRecords() throws {
        let jobId = UUID()
        let record = ExecutionRecord(
            jobId: jobId,
            startedAt: Date(),
            finishedAt: Date().addingTimeInterval(2.3),
            exitCode: 0,
            stdout: "ok",
            stderr: nil
        )
        try store.saveExecution(record)

        let records = try store.loadExecutions(jobId: jobId)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].exitCode, 0)
    }
}
```

**Step 2: Run tests - expect failure**

```bash
swift test --filter DataStoreTests 2>&1 | tail -5
```

**Step 3: Implement data models**

`Sources/CronMonitor/Models/CronJob.swift`:
```swift
import Foundation

struct CronJob: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var cronExpression: String
    var scriptPath: String
    var logPath: String?
    var isEnabled: Bool
    var groupId: UUID?
    let createdAt: Date

    init(id: UUID = UUID(), name: String, cronExpression: String,
         scriptPath: String, logPath: String?, isEnabled: Bool,
         groupId: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.cronExpression = cronExpression
        self.scriptPath = scriptPath
        self.logPath = logPath
        self.isEnabled = isEnabled
        self.groupId = groupId
        self.createdAt = createdAt
    }

    var parsedExpression: CronExpression? {
        try? CronExpression.parse(cronExpression)
    }
}
```

`Sources/CronMonitor/Models/ExecutionRecord.swift`:
```swift
import Foundation

struct ExecutionRecord: Codable, Identifiable {
    let id: UUID
    let jobId: UUID
    let startedAt: Date
    let finishedAt: Date
    let exitCode: Int
    let stdout: String?
    let stderr: String?

    init(id: UUID = UUID(), jobId: UUID, startedAt: Date,
         finishedAt: Date, exitCode: Int,
         stdout: String?, stderr: String?) {
        self.id = id
        self.jobId = jobId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    var isSuccess: Bool { exitCode == 0 }
    var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
}
```

**Step 4: Implement DataStore**

`Sources/CronMonitor/Services/DataStore.swift`:
```swift
import Foundation

class DataStore {
    let baseDir: URL
    private let jobsFile: URL
    private let executionsDir: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDir: URL? = nil) {
        let dir = baseDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cronmonitor")
        self.baseDir = dir
        self.jobsFile = dir.appendingPathComponent("jobs.json")
        self.executionsDir = dir.appendingPathComponent("executions")

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: executionsDir, withIntermediateDirectories: true)
    }

    // MARK: - Jobs

    func loadJobs() throws -> [CronJob] {
        guard FileManager.default.fileExists(atPath: jobsFile.path) else { return [] }
        let data = try Data(contentsOf: jobsFile)
        return try decoder.decode([CronJob].self, from: data)
    }

    func saveJob(_ job: CronJob) throws {
        var jobs = try loadJobs()
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        } else {
            jobs.append(job)
        }
        let data = try encoder.encode(jobs)
        try data.write(to: jobsFile, options: .atomic)
    }

    func deleteJob(id: UUID) throws {
        var jobs = try loadJobs()
        jobs.removeAll { $0.id == id }
        let data = try encoder.encode(jobs)
        try data.write(to: jobsFile, options: .atomic)
    }

    // MARK: - Executions

    func saveExecution(_ record: ExecutionRecord) throws {
        let file = executionsDir.appendingPathComponent("\(record.jobId.uuidString).json")
        var records = try loadExecutions(jobId: record.jobId)
        records.append(record)
        let data = try encoder.encode(records)
        try data.write(to: file, options: .atomic)
    }

    func loadExecutions(jobId: UUID, limit: Int = 50) -> [ExecutionRecord] {
        let file = executionsDir.appendingPathComponent("\(jobId.uuidString).json")
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let records = try? decoder.decode([ExecutionRecord].self, from: data) else {
            return []
        }
        return Array(records.suffix(limit))
    }
}
```

**Step 5: Run tests**

```bash
swift test --filter DataStoreTests
```
Expected: All PASS

**Step 6: Commit**

```bash
git add Sources/CronMonitor/Models/ Sources/CronMonitor/Services/ Tests/
git commit -m "feat: add CronJob/ExecutionRecord models with JSON persistence"
```

---

### Task 5: CrontabManager (Read/Write System Crontab)

**Files:**
- Create: `Sources/CronMonitor/Services/CrontabManager.swift`
- Create: `Tests/CronMonitorTests/CrontabManagerTests.swift`

**Step 1: Write failing tests**

`Tests/CronMonitorTests/CrontabManagerTests.swift`:
```swift
import XCTest
@testable import CronMonitor

final class CrontabManagerTests: XCTestCase {

    func testReadCurrentCrontab() throws {
        let manager = CrontabManager()
        let lines = try manager.readCrontab()
        // Should not throw; returns current user's crontab lines
        XCTAssertTrue(lines is [CrontabLine])
    }

    func testParseCrontabOutput() throws {
        let raw = """
        50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1
        0 9 * * * /usr/local/bin/backup.sh
        # comment line
        """
        let lines = CrontabManager.parseRawCrontab(raw)
        XCTAssertEqual(lines.count, 2)
    }

    func testGenerateCrontabString() {
        let lines = [
            CrontabLine(
                expression: CronExpression(minute: "0", hour: "9", dayOfMonth: "*", month: "*", dayOfWeek: "*"),
                command: "/bin/test.sh"
            )
        ]
        let result = CrontabManager.generateCrontabString(from: lines)
        XCTAssertEqual(result, "0 9 * * * /bin/test.sh\n")
    }
}
```

**Step 2: Run tests - expect failure**

**Step 3: Implement CrontabManager**

`Sources/CronMonitor/Services/CrontabManager.swift`:
```swift
import Foundation

class CrontabManager {

    enum CrontabError: Error {
        case readFailed(String)
        case writeFailed(String)
    }

    func readCrontab() throws -> [CrontabLine] {
        let output = try runProcess("/usr/bin/crontab", arguments: ["-l"])
        return CrontabManager.parseRawCrontab(output)
    }

    func writeCrontab(lines: [CrontabLine]) throws {
        let content = CrontabManager.generateCrontabString(from: lines)
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("crontab_\(UUID().uuidString)")
        try content.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        _ = try runProcess("/usr/bin/crontab", arguments: [tempFile.path])
    }

    static func parseRawCrontab(_ raw: String) -> [CrontabLine] {
        raw.split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line in
                try? CrontabLine.parse(String(line))
            }
    }

    static func generateCrontabString(from lines: [CrontabLine]) -> String {
        lines.map { $0.toString() }.joined(separator: "\n") + "\n"
    }

    private func runProcess(_ path: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw CrontabError.readFailed(errStr)
        }

        return output
    }
}
```

**Step 4: Run tests**

```bash
swift test --filter CrontabManagerTests
```
Expected: All PASS

**Step 5: Commit**

```bash
git add Sources/CronMonitor/Services/CrontabManager.swift Tests/
git commit -m "feat: add CrontabManager for reading/writing system crontab"
```

---

### Task 6: Wrapper Script

**Files:**
- Create: `Sources/CronMonitor/Services/WrapperManager.swift`
- Create: `Resources/wrapper.sh`

**Step 1: Create wrapper shell script**

`Resources/wrapper.sh`:
```bash
#!/bin/bash
# CronMonitor Wrapper Script
# Usage: wrapper.sh <job-id> <data-dir> <script-path> [args...]

JOB_ID="$1"
DATA_DIR="$2"
SCRIPT="$3"
shift 3

EXEC_DIR="${DATA_DIR}/executions"
mkdir -p "$EXEC_DIR"

START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_EPOCH=$(date +%s)

# Run the actual script, capture output
STDOUT=$("$SCRIPT" "$@" 2>/tmp/cronmonitor_stderr_${JOB_ID})
EXIT_CODE=$?
STDERR=$(cat /tmp/cronmonitor_stderr_${JOB_ID} 2>/dev/null)
rm -f /tmp/cronmonitor_stderr_${JOB_ID}

END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
END_EPOCH=$(date +%s)

# Append result as JSON line to execution log
RECORD_FILE="${EXEC_DIR}/${JOB_ID}.jsonl"

# Escape JSON strings
escape_json() {
    printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()), end="")'
}

cat >> "$RECORD_FILE" << JSONEOF
{"jobId":"${JOB_ID}","startedAt":"${START_TIME}","finishedAt":"${END_TIME}","exitCode":${EXIT_CODE},"stdout":$(escape_json "$STDOUT"),"stderr":$(escape_json "$STDERR")}
JSONEOF

exit $EXIT_CODE
```

**Step 2: Implement WrapperManager**

`Sources/CronMonitor/Services/WrapperManager.swift`:
```swift
import Foundation

class WrapperManager {
    let dataDir: URL
    private let wrapperPath: URL

    init(dataDir: URL? = nil) {
        let dir = dataDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cronmonitor")
        self.dataDir = dir
        self.wrapperPath = dir.appendingPathComponent("wrapper.sh")
    }

    func installWrapper() throws {
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let script = Self.wrapperScript
        try script.write(to: wrapperPath, atomically: true, encoding: .utf8)

        // Make executable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", wrapperPath.path]
        try process.run()
        process.waitUntilExit()
    }

    func wrapCommand(jobId: UUID, scriptPath: String) -> String {
        "\(wrapperPath.path) \(jobId.uuidString) \(dataDir.path) \(scriptPath)"
    }

    static let wrapperScript = """
    #!/bin/bash
    JOB_ID="$1"; DATA_DIR="$2"; SCRIPT="$3"; shift 3
    EXEC_DIR="${DATA_DIR}/executions"; mkdir -p "$EXEC_DIR"
    START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    STDOUT=$("$SCRIPT" "$@" 2>/tmp/cronmonitor_stderr_${JOB_ID})
    EXIT_CODE=$?
    STDERR=$(cat /tmp/cronmonitor_stderr_${JOB_ID} 2>/dev/null)
    rm -f /tmp/cronmonitor_stderr_${JOB_ID}
    END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    escape_json() { printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()), end="")'; }
    cat >> "${EXEC_DIR}/${JOB_ID}.jsonl" << JSONEOF
    {"jobId":"${JOB_ID}","startedAt":"${START_TIME}","finishedAt":"${END_TIME}","exitCode":${EXIT_CODE},"stdout":$(escape_json "$STDOUT"),"stderr":$(escape_json "$STDERR")}
    JSONEOF
    exit $EXIT_CODE
    """
}
```

**Step 3: Build and verify**

```bash
swift build
```

**Step 4: Commit**

```bash
git add Sources/CronMonitor/Services/WrapperManager.swift Resources/
git commit -m "feat: add wrapper script for capturing cron execution results"
```

---

### Task 7: AppState ViewModel

**Files:**
- Create: `Sources/CronMonitor/ViewModels/AppState.swift`

**Step 1: Implement central app state**

`Sources/CronMonitor/ViewModels/AppState.swift`:
```swift
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var jobs: [CronJob] = []
    @Published var executions: [UUID: [ExecutionRecord]] = [:]
    @Published var hasFailures: Bool = false

    let dataStore: DataStore
    let crontabManager: CrontabManager
    let wrapperManager: WrapperManager

    init(dataStore: DataStore = DataStore(),
         crontabManager: CrontabManager = CrontabManager(),
         wrapperManager: WrapperManager = WrapperManager()) {
        self.dataStore = dataStore
        self.crontabManager = crontabManager
        self.wrapperManager = wrapperManager
    }

    func loadAll() {
        jobs = (try? dataStore.loadJobs()) ?? []
        for job in jobs {
            executions[job.id] = dataStore.loadExecutions(jobId: job.id)
        }
        updateFailureStatus()
    }

    func lastExecution(for jobId: UUID) -> ExecutionRecord? {
        executions[jobId]?.last
    }

    func addJob(_ job: CronJob) throws {
        try dataStore.saveJob(job)
        try syncToCrontab()
        loadAll()
    }

    func updateJob(_ job: CronJob) throws {
        try dataStore.saveJob(job)
        try syncToCrontab()
        loadAll()
    }

    func deleteJob(_ job: CronJob) throws {
        try dataStore.deleteJob(id: job.id)
        try syncToCrontab()
        loadAll()
    }

    func importFromCrontab() throws {
        let lines = try crontabManager.readCrontab()
        for line in lines {
            let job = CronJob(
                name: URL(fileURLWithPath: line.scriptPath).lastPathComponent,
                cronExpression: line.expression.toString(),
                scriptPath: line.scriptPath,
                logPath: line.logPath,
                isEnabled: true
            )
            try dataStore.saveJob(job)
        }
        loadAll()
    }

    private func syncToCrontab() throws {
        try wrapperManager.installWrapper()
        let lines: [CrontabLine] = jobs.filter(\.isEnabled).map { job in
            let wrappedCmd = wrapperManager.wrapCommand(jobId: job.id, scriptPath: job.scriptPath)
            return CrontabLine(
                expression: job.parsedExpression ?? CronExpression(minute: "0", hour: "0",
                    dayOfMonth: "*", month: "*", dayOfWeek: "*"),
                command: wrappedCmd
            )
        }
        try crontabManager.writeCrontab(lines: lines)
    }

    private func updateFailureStatus() {
        hasFailures = jobs.contains { job in
            lastExecution(for: job.id)?.isSuccess == false
        }
    }
}
```

**Step 2: Build and verify**

```bash
swift build
```

**Step 3: Commit**

```bash
git add Sources/CronMonitor/ViewModels/
git commit -m "feat: add AppState ViewModel for centralized state management"
```

---

### Task 8: Menu Bar UI - Job List View

**Files:**
- Modify: `Sources/CronMonitor/CronMonitorApp.swift`
- Create: `Sources/CronMonitor/Views/JobListView.swift`
- Create: `Sources/CronMonitor/Views/JobCardView.swift`

**Step 1: Implement JobCardView**

`Sources/CronMonitor/Views/JobCardView.swift`:
```swift
import SwiftUI

struct JobCardView: View {
    let job: CronJob
    let lastExecution: ExecutionRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(job.name)
                    .font(.headline)
                Spacer()
                if !job.isEnabled {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let expr = job.parsedExpression {
                Text(expr.humanReadable)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let exec = lastExecution {
                HStack {
                    Text("Last: \(exec.startedAt.formatted(.relative(presentation: .named)))")
                    Text(exec.isSuccess ? "OK" : "Failed (exit \(exec.exitCode))")
                        .foregroundStyle(exec.isSuccess ? .green : .red)
                    Text(String(format: "%.1fs", exec.duration))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            } else {
                Text("Never run")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        guard job.isEnabled else { return .gray }
        guard let exec = lastExecution else { return .gray }
        return exec.isSuccess ? .green : .red
    }
}
```

**Step 2: Implement JobListView**

`Sources/CronMonitor/Views/JobListView.swift`:
```swift
import SwiftUI

struct JobListView: View {
    @ObservedObject var appState: AppState
    @State private var showingAddJob = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("CronMonitor")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddJob = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Job list
            if appState.jobs.isEmpty {
                VStack(spacing: 8) {
                    Text("No jobs configured")
                        .foregroundStyle(.secondary)
                    Button("Import from crontab") {
                        try? appState.importFromCrontab()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.jobs) { job in
                            JobCardView(
                                job: job,
                                lastExecution: appState.lastExecution(for: job.id)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            Divider()

            // Footer
            HStack {
                Button("Refresh") { appState.loadAll() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }
}
```

**Step 3: Update CronMonitorApp**

`Sources/CronMonitor/CronMonitorApp.swift`:
```swift
import SwiftUI

@main
struct CronMonitorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            JobListView(appState: appState)
        } label: {
            Image(systemName: appState.hasFailures ? "clock.badge.exclamationmark" : "clock")
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 360, height: 500)
    }
}
```

**Step 4: Build and run**

```bash
swift build && .build/debug/CronMonitor &
```
Expected: Menu bar icon appears, click shows empty job list with "Import from crontab" button.

**Step 5: Commit**

```bash
git add Sources/CronMonitor/
git commit -m "feat: add Menu Bar UI with job list and card views"
```

---

### Task 9: Job Detail & Edit View

**Files:**
- Create: `Sources/CronMonitor/Views/JobDetailView.swift`
- Modify: `Sources/CronMonitor/Views/JobCardView.swift` (add navigation)

**Step 1: Implement JobDetailView**

`Sources/CronMonitor/Views/JobDetailView.swift`:
```swift
import SwiftUI

struct JobDetailView: View {
    @ObservedObject var appState: AppState
    @State var job: CronJob
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Basic") {
                TextField("Name", text: $job.name)
                Toggle("Enabled", isOn: $job.isEnabled)
            }

            Section("Schedule") {
                TextField("Cron Expression", text: $job.cronExpression)
                if let expr = try? CronExpression.parse(job.cronExpression) {
                    Text(expr.humanReadable)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Script") {
                TextField("Script Path", text: $job.scriptPath)
                HStack {
                    TextField("Log Path (optional)", text: Binding(
                        get: { job.logPath ?? "" },
                        set: { job.logPath = $0.isEmpty ? nil : $0 }
                    ))
                }
            }

            Section("Recent Executions") {
                let records = appState.executions[job.id] ?? []
                if records.isEmpty {
                    Text("No executions yet").foregroundStyle(.secondary)
                } else {
                    ForEach(records.suffix(10).reversed()) { record in
                        HStack {
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Image(systemName: record.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(record.isSuccess ? .green : .red)
                            Text(String(format: "%.1fs", record.duration))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    try? appState.updateJob(job)
                    dismiss()
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    try? appState.deleteJob(job)
                    dismiss()
                }
            }
        }
    }
}
```

**Step 2: Build and verify**

```bash
swift build
```

**Step 3: Commit**

```bash
git add Sources/CronMonitor/Views/
git commit -m "feat: add job detail view with edit form and execution history"
```

---

### Task 10: Add Job View

**Files:**
- Create: `Sources/CronMonitor/Views/AddJobView.swift`
- Modify: `Sources/CronMonitor/Views/JobListView.swift` (connect sheet)

**Step 1: Implement AddJobView**

`Sources/CronMonitor/Views/AddJobView.swift`:
```swift
import SwiftUI

struct AddJobView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var useSimpleMode = true
    @State private var cronExpression = "0 9 * * *"
    @State private var scriptPath = ""
    @State private var frequency = Frequency.daily
    @State private var hour = 9
    @State private var minute = 0

    enum Frequency: String, CaseIterable {
        case everyMinute = "Every minute"
        case hourly = "Every hour"
        case daily = "Every day"
        case weekly = "Every Monday"
    }

    var body: some View {
        Form {
            Section("Basic") {
                TextField("Job Name", text: $name)
            }

            Section("Schedule") {
                Picker("Mode", selection: $useSimpleMode) {
                    Text("Simple").tag(true)
                    Text("Cron Expression").tag(false)
                }
                .pickerStyle(.segmented)

                if useSimpleMode {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(Frequency.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    if frequency != .everyMinute {
                        HStack {
                            Picker("Hour", selection: $hour) {
                                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)) }
                            }
                            Text(":")
                            Picker("Minute", selection: $minute) {
                                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)) }
                            }
                        }
                    }
                    Text("Preview: \(computedCron)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    TextField("Cron Expression", text: $cronExpression)
                    if let expr = try? CronExpression.parse(cronExpression) {
                        Text(expr.humanReadable)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Script") {
                HStack {
                    TextField("Script Path", text: $scriptPath)
                    Button("Browse") { browseFile() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let job = CronJob(
                        name: name,
                        cronExpression: useSimpleMode ? computedCron : cronExpression,
                        scriptPath: scriptPath,
                        logPath: nil,
                        isEnabled: true
                    )
                    try? appState.addJob(job)
                    dismiss()
                }
                .disabled(name.isEmpty || scriptPath.isEmpty)
            }
        }
    }

    private var computedCron: String {
        switch frequency {
        case .everyMinute: return "* * * * *"
        case .hourly: return "\(minute) * * * *"
        case .daily: return "\(minute) \(hour) * * *"
        case .weekly: return "\(minute) \(hour) * * 1"
        }
    }

    private func browseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            scriptPath = panel.url?.path ?? ""
        }
    }
}
```

**Step 2: Connect AddJobView to JobListView sheet**

In `JobListView.swift`, add `.sheet(isPresented: $showingAddJob)` modifier:
```swift
// After the existing .frame(width: 360) modifier
.sheet(isPresented: $showingAddJob) {
    AddJobView(appState: appState)
}
```

**Step 3: Build and run**

```bash
swift build && .build/debug/CronMonitor &
```
Expected: Can click +, fill form, create job.

**Step 4: Commit**

```bash
git add Sources/CronMonitor/Views/
git commit -m "feat: add job creation with simple mode and cron expression mode"
```

---

### Task 11: macOS Notifications

**Files:**
- Create: `Sources/CronMonitor/Services/NotificationManager.swift`
- Modify: `Sources/CronMonitor/CronMonitorApp.swift` (request permission on launch)

**Step 1: Implement NotificationManager**

`Sources/CronMonitor/Services/NotificationManager.swift`:
```swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendFailureNotification(jobName: String, exitCode: Int) {
        let content = UNMutableNotificationContent()
        content.title = "CronMonitor: Job Failed"
        content.body = "\(jobName) exited with code \(exitCode)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

**Step 2: Request permission on app launch**

In `CronMonitorApp.swift` init or onAppear:
```swift
init() {
    NotificationManager.shared.requestPermission()
}
```

**Step 3: Build**

```bash
swift build
```

**Step 4: Commit**

```bash
git add Sources/CronMonitor/Services/NotificationManager.swift Sources/CronMonitor/CronMonitorApp.swift
git commit -m "feat: add macOS notification support for job failures"
```

---

### Task 12: Execution History Polling + Notification Trigger

**Files:**
- Modify: `Sources/CronMonitor/ViewModels/AppState.swift`

**Step 1: Add timer-based polling to AppState**

Add to `AppState`:
```swift
private var pollTimer: Timer?

func startPolling(interval: TimeInterval = 30) {
    pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.checkForNewExecutions()
        }
    }
}

private func checkForNewExecutions() {
    let previousFailures = Set(jobs.compactMap { job -> UUID? in
        guard let exec = lastExecution(for: job.id), !exec.isSuccess else { return nil }
        return exec.id
    })

    loadAll()

    // Check for new failures
    for job in jobs {
        if let exec = lastExecution(for: job.id),
           !exec.isSuccess,
           !previousFailures.contains(exec.id) {
            NotificationManager.shared.sendFailureNotification(
                jobName: job.name, exitCode: exec.exitCode
            )
        }
    }
}

func stopPolling() {
    pollTimer?.invalidate()
    pollTimer = nil
}
```

**Step 2: Start polling in CronMonitorApp onAppear**

**Step 3: Build and verify**

```bash
swift build
```

**Step 4: Commit**

```bash
git add Sources/CronMonitor/ViewModels/AppState.swift
git commit -m "feat: add execution history polling with failure notification trigger"
```

---

### Task 13: Build Script for .app Bundle

**Files:**
- Create: `scripts/build-app.sh`
- Create: `Resources/Info.plist`

**Step 1: Create Info.plist**

`Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>CronMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.cronmonitor</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>CronMonitor</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

Note: `LSUIElement = true` hides the app from the Dock (menu bar only).

**Step 2: Create build script**

`scripts/build-app.sh`:
```bash
#!/bin/bash
set -e

APP_NAME="CronMonitor"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/"

echo "App bundle created at: ${APP_BUNDLE}"
echo "To install: cp -r ${APP_BUNDLE} /Applications/"
```

**Step 3: Build .app bundle**

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

**Step 4: Commit**

```bash
git add scripts/ Resources/Info.plist
git commit -m "feat: add build script for macOS .app bundle with LSUIElement"
```

---

## Summary

| Task | Component | Estimated Steps |
|------|-----------|----------------|
| 1 | Project scaffolding | 6 |
| 2 | Cron expression parser + tests | 5 |
| 3 | Crontab line parser + tests | 5 |
| 4 | Data model + JSON persistence + tests | 6 |
| 5 | CrontabManager + tests | 5 |
| 6 | Wrapper script | 4 |
| 7 | AppState ViewModel | 3 |
| 8 | Menu Bar UI + Job List | 5 |
| 9 | Job Detail/Edit View | 3 |
| 10 | Add Job View | 4 |
| 11 | Notifications | 4 |
| 12 | Execution polling | 4 |
| 13 | .app bundle build script | 4 |
