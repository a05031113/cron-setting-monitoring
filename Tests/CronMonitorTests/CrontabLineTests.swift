import XCTest
@testable import CronMonitor

final class CrontabLineTests: XCTestCase {

    // MARK: - Parsing

    func testParseFullLine() throws {
        let line = "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1"
        let parsed = try CrontabLine.parse(line)

        XCTAssertEqual(parsed.expression, try CronExpression.parse("50 8 * * 1-7"))
        XCTAssertEqual(parsed.command, "/Users/user/script.sh >> /Users/user/log.log 2>&1")
    }

    func testParseLineWithoutRedirect() throws {
        let line = "0 9 * * * /usr/local/bin/backup.sh"
        let parsed = try CrontabLine.parse(line)

        XCTAssertEqual(parsed.expression, try CronExpression.parse("0 9 * * *"))
        XCTAssertEqual(parsed.command, "/usr/local/bin/backup.sh")
    }

    func testParseLineWithComplexCommand() throws {
        let line = "*/5 * * * * cd /tmp && ./run.sh"
        let parsed = try CrontabLine.parse(line)

        XCTAssertEqual(parsed.expression, try CronExpression.parse("*/5 * * * *"))
        XCTAssertEqual(parsed.command, "cd /tmp && ./run.sh")
    }

    // MARK: - Comment and empty lines

    func testParseCommentLine() {
        XCTAssertThrowsError(try CrontabLine.parse("# this is a comment")) { error in
            XCTAssertTrue(error is CronParseError)
        }
    }

    func testParseEmptyLine() {
        XCTAssertThrowsError(try CrontabLine.parse("")) { error in
            XCTAssertTrue(error is CronParseError)
        }
    }

    func testParseWhitespaceOnlyLine() {
        XCTAssertThrowsError(try CrontabLine.parse("   ")) { error in
            XCTAssertTrue(error is CronParseError)
        }
    }

    // MARK: - scriptPath

    func testScriptPath() throws {
        let line = "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1"
        let parsed = try CrontabLine.parse(line)
        XCTAssertEqual(parsed.scriptPath, "/Users/user/script.sh")
    }

    func testScriptPathWithArguments() throws {
        let line = "0 9 * * * /usr/bin/python3 /home/user/script.py --verbose"
        let parsed = try CrontabLine.parse(line)
        XCTAssertEqual(parsed.scriptPath, "/usr/bin/python3")
    }

    // MARK: - logPath

    func testLogPathWithRedirect() throws {
        let line = "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1"
        let parsed = try CrontabLine.parse(line)
        XCTAssertEqual(parsed.logPath, "/Users/user/log.log")
    }

    func testLogPathWithSingleRedirect() throws {
        let line = "0 9 * * * /usr/bin/backup.sh > /var/log/backup.log"
        let parsed = try CrontabLine.parse(line)
        XCTAssertEqual(parsed.logPath, "/var/log/backup.log")
    }

    func testLogPathNilWhenNoRedirect() throws {
        let line = "0 9 * * * /usr/local/bin/backup.sh"
        let parsed = try CrontabLine.parse(line)
        XCTAssertNil(parsed.logPath)
    }

    // MARK: - toString

    func testToStringRoundTrip() throws {
        let line = "50 8 * * 1-7 /Users/user/script.sh >> /Users/user/log.log 2>&1"
        let parsed = try CrontabLine.parse(line)
        XCTAssertEqual(parsed.toString(), line)
    }

    // MARK: - Conformances

    func testEquatable() throws {
        let a = try CrontabLine.parse("0 9 * * * /usr/local/bin/backup.sh")
        let b = try CrontabLine.parse("0 9 * * * /usr/local/bin/backup.sh")
        XCTAssertEqual(a, b)
    }

    func testCodable() throws {
        let parsed = try CrontabLine.parse("0 9 * * * /usr/local/bin/backup.sh")
        let data = try JSONEncoder().encode(parsed)
        let decoded = try JSONDecoder().decode(CrontabLine.self, from: data)
        XCTAssertEqual(parsed, decoded)
    }
}
