import Foundation

/// Reads and writes the current user's crontab via the `crontab` command-line tool.
final class CrontabManager: Sendable {

    enum CrontabError: Error {
        case readFailed(String)
        case writeFailed(String)
    }

    // MARK: - Public API

    /// Read the current user's crontab and return parsed lines.
    /// Empty crontabs (or "no crontab for user") return an empty array.
    func readCrontab() throws -> [CrontabLine] {
        let raw: String
        do {
            raw = try runProcess("/usr/bin/crontab", arguments: ["-l"])
        } catch let error as CrontabError {
            // `crontab -l` exits non-zero when there is no crontab installed.
            // Treat that as an empty crontab rather than a hard error.
            let message: String
            switch error {
            case .readFailed(let msg): message = msg
            case .writeFailed(let msg): message = msg
            }
            if message.contains("no crontab for") {
                return []
            }
            throw error
        }
        return Self.parseRawCrontab(raw)
    }

    /// Write the given lines to the current user's crontab.
    /// Creates a temporary file, writes content, then runs `crontab <tempfile>`.
    func writeCrontab(lines: [CrontabLine]) throws {
        let content = Self.generateCrontabString(from: lines)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crontab-\(UUID().uuidString).tmp")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        _ = try runProcess("/usr/bin/crontab", arguments: [tempURL.path])
    }

    // MARK: - Static helpers

    /// Parse raw crontab output into an array of CrontabLine, skipping comments and empty lines.
    static func parseRawCrontab(_ raw: String) -> [CrontabLine] {
        raw.components(separatedBy: .newlines).compactMap { line in
            try? CrontabLine.parse(line)
        }
    }

    /// Generate a crontab file content string from an array of CrontabLine.
    /// Each line is separated by a newline and the output ends with a trailing newline.
    static func generateCrontabString(from lines: [CrontabLine]) -> String {
        lines.map { $0.toString() }.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    /// Run an external process and return its stdout. Throws CrontabError on non-zero exit.
    private func runProcess(_ path: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let detail = stderrStr.isEmpty ? stdoutStr : stderrStr
            throw CrontabError.readFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return stdoutStr
    }
}
