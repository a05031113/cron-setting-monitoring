import SwiftUI

/// View for creating a new cron job with simple or advanced cron expression input.
struct AddJobView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var scriptPath = ""
    @State private var scheduleMode: ScheduleMode = .simple
    @State private var frequency: Frequency = .daily
    @State private var hour = 0
    @State private var minute = 0
    @State private var cronExpression = "* * * * *"

    enum ScheduleMode: String, CaseIterable {
        case simple = "Simple"
        case cron = "Cron Expression"
    }

    enum Frequency: String, CaseIterable {
        case everyMinute = "Every minute"
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Text("Add Job")
                    .font(.headline)
                Spacer()
                Button("Create") {
                    createJob()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || scriptPath.isEmpty)
            }
            .padding()

            Form {
                Section("Basic") {
                    TextField("Name", text: $name)
                }

                Section("Schedule") {
                    Picker("Mode", selection: $scheduleMode) {
                        ForEach(ScheduleMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if scheduleMode == .simple {
                        Picker("Frequency", selection: $frequency) {
                            ForEach(Frequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }

                        if frequency == .daily || frequency == .weekly {
                            HStack {
                                Picker("Hour", selection: $hour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02d", h)).tag(h)
                                    }
                                }
                                .frame(width: 80)
                                Picker("Minute", selection: $minute) {
                                    ForEach(0..<60, id: \.self) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .frame(width: 80)
                            }
                        } else if frequency == .hourly {
                            Picker("Minute", selection: $minute) {
                                ForEach(0..<60, id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .frame(width: 80)
                        }

                        Text("Preview: \(computedCron)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Cron Expression", text: $cronExpression)
                        if let parsed = try? CronExpression.parse(cronExpression) {
                            Text(parsed.humanReadable)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Script") {
                    HStack {
                        TextField("Script Path", text: $scriptPath)
                        Button("Browse...") {
                            browseForScript()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 400)
    }

    private var computedCron: String {
        switch frequency {
        case .everyMinute:
            return "* * * * *"
        case .hourly:
            return "\(minute) * * * *"
        case .daily:
            return "\(minute) \(hour) * * *"
        case .weekly:
            return "\(minute) \(hour) * * 1"
        }
    }

    private func createJob() {
        let finalCron = scheduleMode == .simple ? computedCron : cronExpression
        let job = CronJob(
            name: name,
            cronExpression: finalCron,
            scriptPath: scriptPath
        )
        do {
            try appState.addJob(job)
        } catch {
            // Handle error silently for now
        }
        dismiss()
    }

    private func browseForScript() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select Script"
        if panel.runModal() == .OK, let url = panel.url {
            scriptPath = url.path
        }
    }
}
