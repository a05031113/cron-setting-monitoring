import SwiftUI

@main
struct CronMonitorApp: App {
    var body: some Scene {
        MenuBarExtra("CronMonitor", systemImage: "clock") {
            Text("CronMonitor is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
