import SwiftUI

/// A card displaying a single cron job's status summary.
struct JobCardView: View {
    let job: CronJob
    let lastExecution: ExecutionRecord?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.name)
                        .font(.headline)
                    if !job.isEnabled {
                        Text("Paused")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if let parsed = job.parsedExpression {
                    Text(parsed.humanReadable)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let exec = lastExecution {
                    HStack(spacing: 4) {
                        Text(exec.startedAt, style: .relative)
                        Text("ago")
                        Image(systemName: exec.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(exec.isSuccess ? .green : .red)
                            .font(.caption)
                        Text(formattedDuration(exec.duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Never run")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        if !job.isEnabled {
            return .gray
        }
        guard let exec = lastExecution else {
            return .gray
        }
        return exec.isSuccess ? .green : .red
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
