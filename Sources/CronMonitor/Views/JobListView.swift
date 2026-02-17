import SwiftUI

/// The main menu bar popover view showing all monitored cron jobs.
struct JobListView: View {
    @ObservedObject var appState: AppState

    @State private var showingAddJob = false
    @State private var showingSettings = false
    @State private var selectedJob: CronJob?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CronMonitor")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddJob = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add Job")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Content
            if appState.jobs.isEmpty {
                VStack(spacing: 12) {
                    Text("No jobs configured")
                        .foregroundStyle(.secondary)
                    Button("Import from crontab") {
                        do {
                            try appState.importFromCrontab()
                        } catch {
                            // Silently handle import errors for now
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.jobs) { job in
                            JobCardView(
                                job: job,
                                lastExecution: appState.lastExecution(for: job.id)
                            )
                            .onTapGesture {
                                selectedJob = job
                            }

                            if job.id != appState.jobs.last?.id {
                                Divider()
                                    .padding(.horizontal, 10)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Footer
            HStack {
                Button {
                    appState.loadAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .buttonStyle(.borderless)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appState.loadAll()
        }
        .sheet(isPresented: $showingAddJob) {
            AddJobView(appState: appState)
        }
        .sheet(item: $selectedJob) { job in
            JobDetailView(appState: appState, job: job)
        }
    }
}
