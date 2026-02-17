# CronMonitor - Project Instructions

## Project Overview

macOS native app (SwiftUI) for visually managing and monitoring crontab jobs on the local Mac.

## Tech Stack

- **Language**: Swift 6.2 (strict concurrency enabled)
- **UI**: SwiftUI with `WindowGroup`
- **Package Manager**: SPM (Package.swift, swift-tools-version: 6.0)
- **Xcode Project**: Generated via `xcodegen` from `project.yml`
- **Min OS**: macOS 14 (Sonoma)
- **Data Storage**: JSON files in `~/.cronmonitor/`
- **Tests**: XCTest, 57 tests

## Architecture

```
CronMonitorApp (@main, WindowGroup)
  └─ AppState (@MainActor, ObservableObject) ── central state
       ├─ DataStore ──────── JSON persistence (~/.cronmonitor/)
       ├─ CrontabManager ── read/write system crontab via Process
       └─ WrapperManager ── shell wrapper for execution tracking
```

### Layer Responsibilities

| Layer | Directory | Role |
|-------|-----------|------|
| Models | `Sources/CronMonitor/Models/` | Data structs (all `Codable, Sendable`) |
| Services | `Sources/CronMonitor/Services/` | Business logic, system interaction |
| ViewModels | `Sources/CronMonitor/ViewModels/` | `AppState` — single ViewModel, `@MainActor` |
| Views | `Sources/CronMonitor/Views/` | SwiftUI views, no business logic |

### Key Files

| File | Purpose |
|------|---------|
| `CronExpression.swift` | Parse cron expressions, humanize (`"0 9 * * *"` → `"Every day at 09:00"`), calculate next run |
| `CrontabLine.swift` | Parse full crontab lines, extract script/log paths |
| `CronJob.swift` | Job model (name, cronExpression, scriptPath, isEnabled) |
| `ExecutionRecord.swift` | Execution result (exitCode, duration, stdout/stderr) |
| `DataStore.swift` | JSON file I/O: `jobs.json` + `executions/{jobId}.json` |
| `CrontabManager.swift` | `crontab -l` / `crontab <file>` via `Process` |
| `WrapperManager.swift` | Generates wrapper.sh that captures execution results |
| `AppState.swift` | Central state: CRUD jobs, sync to crontab, poll executions, trigger notifications |

## Build & Run

```bash
# SPM build
swift build

# Run tests
swift test

# Xcode (recommended for GUI)
xcodegen generate   # regenerate .xcodeproj if project.yml changed
open CronMonitor.xcodeproj  # Cmd+R to run

# Release .app bundle
./scripts/build-app.sh
```

## Data Flow

1. **Read**: `crontab -l` → `CrontabManager.parseRawCrontab()` → `[CrontabLine]`
2. **Create/Edit**: UI form → `AppState.addJob()` → `DataStore.saveJob()` → `CrontabManager.writeCrontab()`
3. **Monitor**: `wrapper.sh` runs user script → writes result to `executions/{jobId}.json`
4. **Poll**: `AppState.startPolling()` (30s interval) → detects new failures → `NotificationManager`

## Swift 6 Concurrency Notes

- All model structs are `Sendable` (immutable value types)
- `AppState` is `@MainActor` — all state mutations on main thread
- `DataStore` is NOT `Sendable` — only used from `@MainActor`
- `CrontabManager` and `NotificationManager` are `Sendable` (no mutable state)
- Timer callback in `AppState.startPolling()` dispatches via `Task { @MainActor in ... }`

## Known Limitations / TODO

- [ ] Wrapper integration: `syncToCrontab()` currently writes scriptPath directly, not through wrapper
- [ ] Smart grouping: same script + similar schedule should merge into one card
- [ ] Login Items: auto-start on boot not yet implemented
- [ ] stdout/stderr viewer in execution detail
- [ ] Confirm dialog before overwriting existing crontab on import
- [ ] Error handling in UI (import failures, crontab write failures)
- [ ] App icon not yet wired into SPM builds (only works via Xcode project)

## Conventions

- Commit messages: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- Tests: XCTest with table-driven style where applicable
- No external dependencies (pure Apple frameworks)
- Xcode project regeneration: edit `project.yml` then `xcodegen generate`
