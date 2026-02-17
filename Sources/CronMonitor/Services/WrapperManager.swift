import Foundation

/// Manages the installation and usage of the cron wrapper shell script.
///
/// The wrapper script is placed at `dataDir/wrapper.sh` and is used to
/// wrap cron job commands so that execution records (start time, end time,
/// exit code, stdout, stderr) are captured and persisted as JSON.
final class WrapperManager {
    private let dataDir: URL

    /// The path to the installed wrapper script.
    var wrapperPath: String {
        dataDir.appendingPathComponent("wrapper.sh").path
    }

    /// Initialize the wrapper manager.
    /// - Parameter dataDir: Root directory for data files. Defaults to `~/.cronmonitor/`.
    init(dataDir: URL? = nil) {
        self.dataDir = dataDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cronmonitor")
    }

    /// Write the wrapper shell script to `dataDir/wrapper.sh` and make it executable.
    func installWrapper() throws {
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let wrapperURL = dataDir.appendingPathComponent("wrapper.sh")
        try Self.wrapperScript.write(to: wrapperURL, atomically: true, encoding: .utf8)

        // chmod +x
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: wrapperURL.path)
    }

    /// Returns the crontab command string that wraps the given script.
    /// - Parameters:
    ///   - jobId: The UUID of the cron job.
    ///   - scriptPath: The original script/command path to execute.
    /// - Returns: A command string suitable for crontab: `"{wrapperPath} {jobId} {dataDir} {scriptPath}"`
    func wrapCommand(jobId: UUID, scriptPath: String) -> String {
        "\(wrapperPath) \(jobId.uuidString) \(dataDir.path) \(scriptPath)"
    }

    // MARK: - Shell Script

    /// The wrapper shell script content.
    static let wrapperScript: String = """
        #!/bin/bash
        # CronMonitor wrapper script
        # Usage: wrapper.sh <job-id> <data-dir> <script-path>
        set -o pipefail

        JOB_ID="$1"
        DATA_DIR="$2"
        SCRIPT_PATH="$3"

        if [ -z "$JOB_ID" ] || [ -z "$DATA_DIR" ] || [ -z "$SCRIPT_PATH" ]; then
            echo "Usage: $0 <job-id> <data-dir> <script-path>" >&2
            exit 1
        fi

        EXECUTIONS_DIR="${DATA_DIR}/executions"
        EXEC_FILE="${EXECUTIONS_DIR}/${JOB_ID}.json"

        mkdir -p "$EXECUTIONS_DIR"

        # Helper: escape a string for JSON using python3.
        json_escape() {
            printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()), end="")'
        }

        # Record start time (ISO 8601 UTC).
        STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Run the user's script, capturing stdout and stderr separately.
        STDOUT_FILE=$(mktemp)
        STDERR_FILE=$(mktemp)

        /bin/bash "$SCRIPT_PATH" >"$STDOUT_FILE" 2>"$STDERR_FILE"
        EXIT_CODE=$?

        # Record end time.
        FINISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        STDOUT_CONTENT=$(cat "$STDOUT_FILE")
        STDERR_CONTENT=$(cat "$STDERR_FILE")
        rm -f "$STDOUT_FILE" "$STDERR_FILE"

        # Generate a UUID for this execution record.
        EXEC_ID=$(uuidgen | tr '[:lower:]' '[:upper:]')

        # Build JSON for stdout/stderr (use null if empty, quoted string otherwise).
        if [ -z "$STDOUT_CONTENT" ]; then
            STDOUT_JSON="null"
        else
            STDOUT_JSON=$(json_escape "$STDOUT_CONTENT")
        fi

        if [ -z "$STDERR_CONTENT" ]; then
            STDERR_JSON="null"
        else
            STDERR_JSON=$(json_escape "$STDERR_CONTENT")
        fi

        # Build the new record JSON.
        NEW_RECORD=$(cat <<ENDJSON
        {
          "id" : "${EXEC_ID}",
          "jobId" : "${JOB_ID}",
          "startedAt" : "${STARTED_AT}",
          "finishedAt" : "${FINISHED_AT}",
          "exitCode" : ${EXIT_CODE},
          "stdout" : ${STDOUT_JSON},
          "stderr" : ${STDERR_JSON}
        }
        ENDJSON
        )

        # Read existing array or start with empty array, append record, write back.
        if [ -f "$EXEC_FILE" ]; then
            EXISTING=$(cat "$EXEC_FILE")
        else
            EXISTING="[]"
        fi

        # Use python3 to safely append the new record to the JSON array.
        UPDATED=$(python3 -c "
        import sys, json
        existing = json.loads(sys.argv[1])
        new_record = json.loads(sys.argv[2])
        existing.append(new_record)
        print(json.dumps(existing, indent=2))
        " "$EXISTING" "$NEW_RECORD")

        echo "$UPDATED" > "$EXEC_FILE"

        # Exit with the original script's exit code.
        exit $EXIT_CODE
        """
}
