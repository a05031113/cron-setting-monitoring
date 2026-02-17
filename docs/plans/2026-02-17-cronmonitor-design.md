# CronMonitor - macOS Cron Job Management App

## Overview

A macOS Menu Bar app (SwiftUI) for visually managing and monitoring crontab jobs on the local machine.

## Core Requirements

- **Scope**: Local Mac only, independent shell scripts (no DAG/dependencies)
- **Interface**: macOS native Menu Bar App (SwiftUI)
- **Key Features**: Visual cron management, execution monitoring, failure notifications

## Architecture

### App Type
Menu Bar App, no Dock icon. Popover + detachable window.

### Components

| Component | Responsibility |
|-----------|---------------|
| CronManager | Read/write crontab via `Process`, CRUD operations |
| LogMonitor | Monitor wrapper output, parse exit codes |
| SQLite (SwiftData) | Store job metadata, execution history, settings |
| Wrapper Script | Wrap user scripts to capture exit code, duration, stdout/stderr |
| UserNotifications | Push macOS notifications on failure |

### Data Flow

1. Read: `crontab -l` → parse cron expressions → display in UI
2. Create/Edit: UI form → assemble cron line → write via `crontab`
3. Monitor: Wrapper script runs user script → logs result to SQLite
4. Notify: Failed execution → macOS notification

### Wrapper Mechanism

crontab calls our wrapper instead of user script directly:
```
# Original:
50 8 * * 1-7 /path/to/script.sh >> /path/to/log 2>&1

# Managed:
50 8 * * 1-7 ~/.cronmonitor/wrapper.sh <job-id> /path/to/script.sh
```

Wrapper records: start time, end time, exit code, stdout/stderr to SQLite.

## UI Design

### Views

1. **Menu Bar Popover** - Job list with status cards (name, schedule summary, last result, next run)
2. **Job Detail/Edit** - Full job config, cron expression (simple + advanced mode), execution history
3. **Add Job** - Form with simple mode (frequency/time) and cron expression mode, live preview
4. **Settings** - Auto-start, notification prefs, data retention, import existing crontab

### Status Indicators

- Menu bar icon: normal / red dot (failure) / spinning (running)
- Job cards: green (ok) / red (failed) / gray (never run)

### Smart Grouping

Auto-detect same script + similar schedule → group as one logical job (e.g., 5 crontab lines at 08:50-08:58 every 2min → one card).

### Cron Expression Humanization

`50 8 * * 1-7` → "Every day at 08:50"
Simple mode covers 80% use cases; advanced mode for direct cron editing.

## Tech Stack

| Aspect | Choice |
|--------|--------|
| UI | SwiftUI |
| Data | SwiftData (SQLite) |
| Min OS | macOS 14 (Sonoma) |
| Crontab | Process + shell |
| Notifications | UserNotifications framework |

## Data Model

### Job
- id: UUID
- name: String
- cronExpression: String
- scriptPath: String
- logPath: String?
- isEnabled: Bool
- groupId: UUID? (for smart grouping)
- createdAt: Date

### ExecutionRecord
- id: UUID
- jobId: UUID (FK)
- startedAt: Date
- finishedAt: Date
- exitCode: Int
- stdout: String?
- stderr: String?

### AppSettings
- autoStart: Bool
- notifyOnFailure: Bool
- retentionDays: Int
