import SwiftUI

@main
struct CronMonitorApp: App {
    @StateObject private var appState = AppState()

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            JobListView(appState: appState)
                .onAppear { appState.startPolling() }
                .frame(minWidth: 400, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 450, height: 600)
    }
}
