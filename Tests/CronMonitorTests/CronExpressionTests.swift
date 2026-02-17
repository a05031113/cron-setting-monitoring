import XCTest
@testable import CronMonitor

final class CronExpressionTests: XCTestCase {

    // MARK: - Parsing

    func testParseBasicExpression() throws {
        let expr = try CronExpression.parse("50 8 * * 1-7")
        XCTAssertEqual(expr.minute, "50")
        XCTAssertEqual(expr.hour, "8")
        XCTAssertEqual(expr.dayOfMonth, "*")
        XCTAssertEqual(expr.month, "*")
        XCTAssertEqual(expr.dayOfWeek, "1-7")
    }

    func testParseEveryDayAt9() throws {
        let expr = try CronExpression.parse("0 9 * * *")
        XCTAssertEqual(expr.minute, "0")
        XCTAssertEqual(expr.hour, "9")
        XCTAssertEqual(expr.dayOfMonth, "*")
        XCTAssertEqual(expr.month, "*")
        XCTAssertEqual(expr.dayOfWeek, "*")
    }

    func testParseEvery5Minutes() throws {
        let expr = try CronExpression.parse("*/5 * * * *")
        XCTAssertEqual(expr.minute, "*/5")
        XCTAssertEqual(expr.hour, "*")
    }

    func testParseExtraWhitespace() throws {
        let expr = try CronExpression.parse("  0   9   *   *   *  ")
        XCTAssertEqual(expr.minute, "0")
        XCTAssertEqual(expr.hour, "9")
    }

    func testParseInvalidTooFewFields() {
        XCTAssertThrowsError(try CronExpression.parse("0 9 *")) { error in
            XCTAssertTrue(error is CronParseError)
        }
    }

    func testParseEmptyString() {
        XCTAssertThrowsError(try CronExpression.parse("")) { error in
            XCTAssertTrue(error is CronParseError)
        }
    }

    // MARK: - toString

    func testToStringRoundTrip() throws {
        let raw = "50 8 * * 1-7"
        let expr = try CronExpression.parse(raw)
        XCTAssertEqual(expr.toString(), raw)
    }

    func testToStringEveryDay() throws {
        let raw = "0 9 * * *"
        let expr = try CronExpression.parse(raw)
        XCTAssertEqual(expr.toString(), raw)
    }

    // MARK: - humanReadable

    func testHumanReadableEveryDayAt09() throws {
        let expr = try CronExpression.parse("0 9 * * *")
        XCTAssertEqual(expr.humanReadable, "Every day at 09:00")
    }

    func testHumanReadableMonSunAt0850() throws {
        let expr = try CronExpression.parse("50 8 * * 1-7")
        XCTAssertEqual(expr.humanReadable, "Mon-Sun at 08:50")
    }

    func testHumanReadableEvery5Minutes() throws {
        let expr = try CronExpression.parse("*/5 * * * *")
        XCTAssertEqual(expr.humanReadable, "Every 5 minutes")
    }

    func testHumanReadableSingleDayOfWeek() throws {
        let expr = try CronExpression.parse("0 9 * * 1")
        XCTAssertEqual(expr.humanReadable, "Mon at 09:00")
    }

    func testHumanReadableEveryMinute() throws {
        let expr = try CronExpression.parse("* * * * *")
        XCTAssertEqual(expr.humanReadable, "Every minute")
    }

    func testHumanReadableEveryHour() throws {
        let expr = try CronExpression.parse("0 * * * *")
        XCTAssertEqual(expr.humanReadable, "Every hour")
    }

    func testHumanReadableSpecificDayOfMonth() throws {
        let expr = try CronExpression.parse("0 9 15 * *")
        XCTAssertEqual(expr.humanReadable, "Day 15 at 09:00")
    }

    // MARK: - nextRun

    func testNextRunBasic() throws {
        let expr = try CronExpression.parse("0 9 * * *")
        // Create a date: 2026-02-17 08:00 UTC
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 17
        components.hour = 8
        components.minute = 0
        components.timeZone = TimeZone(identifier: "UTC")
        let after = Calendar.current.date(from: components)!

        let next = expr.nextRun(after: after)
        XCTAssertNotNil(next)

        let cal = Calendar.current
        let nextComponents = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: next!)
        XCTAssertEqual(nextComponents.hour, 9)
        XCTAssertEqual(nextComponents.minute, 0)
        XCTAssertEqual(nextComponents.day, 17) // same day, since 9:00 is after 8:00
    }

    func testNextRunAfterTime() throws {
        let expr = try CronExpression.parse("0 9 * * *")
        // Create a date: 2026-02-17 10:00 UTC (after 9:00)
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 17
        components.hour = 10
        components.minute = 0
        components.timeZone = TimeZone(identifier: "UTC")
        let after = Calendar.current.date(from: components)!

        let next = expr.nextRun(after: after)
        XCTAssertNotNil(next)

        let cal = Calendar.current
        let nextComponents = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: next!)
        XCTAssertEqual(nextComponents.hour, 9)
        XCTAssertEqual(nextComponents.minute, 0)
        XCTAssertEqual(nextComponents.day, 18) // next day
    }

    // MARK: - Conformances

    func testEquatable() throws {
        let a = try CronExpression.parse("0 9 * * *")
        let b = try CronExpression.parse("0 9 * * *")
        XCTAssertEqual(a, b)
    }

    func testCodable() throws {
        let expr = try CronExpression.parse("50 8 * * 1-7")
        let data = try JSONEncoder().encode(expr)
        let decoded = try JSONDecoder().decode(CronExpression.self, from: data)
        XCTAssertEqual(expr, decoded)
    }
}
