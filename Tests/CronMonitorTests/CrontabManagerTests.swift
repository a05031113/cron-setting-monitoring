import XCTest
@testable import CronMonitor

final class CrontabManagerTests: XCTestCase {

    // MARK: - readCrontab

    func testReadCurrentCrontab() throws {
        let manager = CrontabManager()
        // Should not throw — reads the actual system crontab (may be empty).
        let lines = try manager.readCrontab()
        // We can't assert specific content, but lines should be a valid array.
        XCTAssertNotNil(lines)
    }

    // MARK: - parseRawCrontab

    func testParseCrontabOutput() {
        let raw = """
        # This is a comment
        50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1

        0 9 * * * /usr/local/bin/backup.sh
        # Another comment
        */5 * * * * cd /tmp && ./run.sh
        """

        let lines = CrontabManager.parseRawCrontab(raw)

        XCTAssertEqual(lines.count, 3)

        // First valid line
        XCTAssertEqual(lines[0].expression.minute, "50")
        XCTAssertEqual(lines[0].expression.hour, "8")
        XCTAssertEqual(lines[0].command, "/Users/user/script.sh >> /Users/user/log.log 2>&1")

        // Second valid line
        XCTAssertEqual(lines[1].expression.minute, "0")
        XCTAssertEqual(lines[1].expression.hour, "9")
        XCTAssertEqual(lines[1].command, "/usr/local/bin/backup.sh")

        // Third valid line
        XCTAssertEqual(lines[2].expression.minute, "*/5")
        XCTAssertEqual(lines[2].command, "cd /tmp && ./run.sh")
    }

    func testParseCrontabOutputEmptyString() {
        let lines = CrontabManager.parseRawCrontab("")
        XCTAssertEqual(lines.count, 0)
    }

    func testParseCrontabOutputOnlyComments() {
        let raw = """
        # comment 1
        # comment 2
        """
        let lines = CrontabManager.parseRawCrontab(raw)
        XCTAssertEqual(lines.count, 0)
    }

    // MARK: - generateCrontabString

    func testGenerateCrontabString() throws {
        let line1 = try CrontabLine.parse("50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1")
        let line2 = try CrontabLine.parse("0 9 * * * /usr/local/bin/backup.sh")

        let result = CrontabManager.generateCrontabString(from: [line1, line2])

        let expected = "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1\n0 9 * * * /usr/local/bin/backup.sh\n"
        XCTAssertEqual(result, expected)
    }

    func testGenerateCrontabStringEmpty() {
        let result = CrontabManager.generateCrontabString(from: [])
        XCTAssertEqual(result, "\n")
    }

    func testGenerateCrontabStringSingleLine() throws {
        let line = try CrontabLine.parse("*/5 * * * * cd /tmp && ./run.sh")
        let result = CrontabManager.generateCrontabString(from: [line])
        XCTAssertEqual(result, "*/5 * * * * cd /tmp && ./run.sh\n")
    }
}
