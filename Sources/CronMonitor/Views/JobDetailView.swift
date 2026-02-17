import SwiftUI

/// Detail and edit view for a single cron job.
struct JobDetailView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let job: CronJob

    @State private var name: String
    @State private var isEnabled: Bool
    @State private var cronExpression: String
    @State private var scriptPath: String
    @State private var logPath: String
    @State private var showDeleteConfirmation = false

    init(appState: AppState, job: CronJob) {
        self.appState = appState
        self.job = job
        _name = State(initialValue: job.name)
        _isEnabled = State(initialValue: job.isEnabled)
        _cronExpression = State(initialValue: job.cronExpression)
        _scriptPath = State(initialValue: job.scriptPath)
        _logPath = State(initialValue: job.logPath ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Text("Job Details")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    saveJob()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || scriptPath.isEmpty)
            }
            .padding()

            Form {
                Section("Basic") {
                    TextField("Name", text: $name)
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Schedule") {
                    TextField("Cron Expression", text: $cronExpression)
                    if let parsed = try? CronExpression.parse(cronExpression) {
                        Text(parsed.humanReadable)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Script") {
                    TextField("Script Path", text: $scriptPath)
                    TextField("Log Path (optional)", text: $logPath)
                }

                Section("Recent Executions") {
                    let records = recentExecutions
                    if records.isEmpty {
                        Text("No executions recorded")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            HStack {
                                Text(record.startedAt, style: .date)
                                Text(record.startedAt, style: .time)
                                Spacer()
                                Image(systemName: record.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(record.isSuccess ? .green : .red)
                                Text(formattedDuration(record.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            // Delete button
            HStack {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Job", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .alert("Delete Job", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteJob()
            }
        } message: {
            Text("Are you sure you want to delete \"\(job.name)\"? This cannot be undone.")
        }
    }

    private var recentExecutions: [ExecutionRecord] {
        let records = appState.executions[job.id] ?? []
        return Array(records.suffix(10).reversed())
    }

    private func saveJob() {
        var updated = job
        updated.name = name
        updated.isEnabled = isEnabled
        updated.cronExpression = cronExpression
        updated.scriptPath = scriptPath
        updated.logPath = logPath.isEmpty ? nil : logPath
        do {
            try appState.updateJob(updated)
        } catch {
            // Handle error silently for now
        }
        dismiss()
    }

    private func deleteJob() {
        do {
            try appState.deleteJob(job)
        } catch {
            // Handle error silently for now
        }
        dismiss()
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(mins)m \(secs)s"
        }
    }
}
