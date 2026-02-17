// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CronMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CronMonitor",
            path: "Sources/CronMonitor"
        ),
        .testTarget(
            name: "CronMonitorTests",
            dependencies: ["CronMonitor"],
            path: "Tests/CronMonitorTests"
        ),
    ]
)
