import SwiftUI

@main
struct CronMonitorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            JobListView(appState: appState)
        } label: {
            Image(systemName: appState.hasFailures ? "clock.badge.exclamationmark" : "clock")
        }
        .menuBarExtraStyle(.window)
    }
}
