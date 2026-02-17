import SwiftUI

@main
struct CronMonitorApp: App {
    @StateObject private var appState = AppState()

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            JobListView(appState: appState)
                .onAppear { appState.startPolling() }
        } label: {
            Image(systemName: appState.hasFailures ? "clock.badge.exclamationmark" : "clock")
        }
        .menuBarExtraStyle(.window)
    }
}
