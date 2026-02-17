# CronMonitor

A native macOS app for visually managing and monitoring crontab jobs. No more editing raw cron expressions in the terminal.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Visual cron management** - Add, edit, delete cron jobs through a native UI
- **Human-readable schedules** - `50 8 * * 1-7` displays as "Mon-Sun at 08:50"
- **Execution monitoring** - Track success/failure, exit codes, and duration of each run
- **macOS notifications** - Get notified when a job fails
- **Import existing crontab** - One-click import of your current cron jobs
- **Simple + Advanced mode** - Pick a frequency from a dropdown, or write cron expressions directly

## Screenshots

> Coming soon

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16+ (for building from source)

## Installation

### Option A: Build from source (recommended)

```bash
# 1. Clone the repo
git clone https://github.com/a05031113/cron-setting-monitoring.git
cd cron-setting-monitoring

# 2. Build and run with Xcode
open CronMonitor.xcodeproj
# Select the CronMonitor scheme, then press Cmd+R
```

If you don't have the Xcode project file, regenerate it:

```bash
# Install xcodegen (one-time)
brew install xcodegen

# Generate Xcode project
xcodegen generate
open CronMonitor.xcodeproj
```

### Option B: Build .app bundle via command line

```bash
# Build release
./scripts/build-app.sh

# Install to Applications
cp -r .build/release/CronMonitor.app /Applications/

# Run
open /Applications/CronMonitor.app
```

> Note: The command-line build produces an unsigned app. On first launch, right-click the app > Open > confirm to bypass Gatekeeper.

## How It Works

### Architecture

```
CronMonitor.app
  |
  |- CronExpression     Parse & humanize cron expressions
  |- CrontabLine        Parse full crontab lines (script path, log path)
  |- CrontabManager     Read/write system crontab via Process
  |- WrapperManager     Shell wrapper that captures execution results
  |- DataStore          JSON file persistence (~/.cronmonitor/)
  |- AppState           Central ViewModel (ObservableObject)
  `- SwiftUI Views      JobList, JobDetail, AddJob
```

### Data Storage

All data is stored locally in `~/.cronmonitor/`:

```
~/.cronmonitor/
  |- jobs.json              # Job definitions
  |- executions/
  |    |- {job-id}.json     # Execution history per job
  `- wrapper.sh             # Shell wrapper for monitoring
```

### Execution Monitoring

When you create a job through CronMonitor, it wraps your script with a monitoring shell script:

```
# Your script runs normally, but CronMonitor tracks:
- Start/end time
- Exit code (0 = success)
- stdout/stderr output
```

## Development

```bash
# Run tests
swift test

# Build debug
swift build

# Build release
swift build -c release
```

### Project Structure

```
Sources/CronMonitor/
  |- CronMonitorApp.swift       # App entry point (WindowGroup)
  |- Models/
  |    |- CronExpression.swift  # Cron parser + humanizer
  |    |- CrontabLine.swift     # Full crontab line parser
  |    |- CronJob.swift         # Job data model
  |    `- ExecutionRecord.swift # Execution history model
  |- Services/
  |    |- DataStore.swift       # JSON persistence
  |    |- CrontabManager.swift  # System crontab read/write
  |    |- WrapperManager.swift  # Execution wrapper
  |    `- NotificationManager.swift
  |- ViewModels/
  |    `- AppState.swift        # Central state management
  `- Views/
       |- JobListView.swift     # Main job list
       |- JobCardView.swift     # Individual job card
       |- JobDetailView.swift   # Job detail/edit
       `- AddJobView.swift      # Add new job form
```

## License

MIT
