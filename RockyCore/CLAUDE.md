# RockyCore — Claude Code Instructions

## Purpose

RockyCore is the shared business logic layer. It has no knowledge of the CLI or any UI. It is imported by both `RockyCLI` and eventually `Rocky`.

## Rules

- **No CLI imports** — do not import ArgumentParser or any CLI-specific package here
- **No UI imports** — do not import SwiftCrossUI or any UI framework here
- **No print statements** — RockyCore never writes to stdout. All output goes through RockyCLI
- **Raw SQL only** — use sqlite-nio directly, no ORM, no query builders
- **Async/await throughout** — all database calls must be async
- **Errors must throw** — never silently swallow errors, always throw or propagate

## Package structure

```
RockyCore/
├── Package.swift
└── Sources/
    └── RockyCore/
        ├── Database/
        │   ├── Database.swift          ← connection setup, db path (~/.rocky/rocky.db)
        │   └── Migrations.swift        ← migration runner, schema creation
        ├── Models/
        │   ├── Project.swift           ← Project struct (id, parentId, name, createdAt)
        │   └── Session.swift           ← Session struct (id, projectId, startTime, endTime)
        └── Services/
            ├── ProjectService.swift    ← findOrCreate, list, getByName
            ├── SessionService.swift    ← start, stop, stopAll, getRunning
            └── ReportService.swift     ← totals, grouping by day/week/month/year
```

## Dependency

```swift
// Package.swift
.package(url: "https://github.com/vapor/sqlite-nio.git", from: "1.0.0")
```

## Database location

```swift
// Always use this path
let dbPath = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent(".rocky/rocky.db")
    .path
```

Create `~/.rocky/` if it does not exist on first run.

## Schema

See `../RockyDocs/SCHEMA.md` for the full schema. Do not modify the schema without reading that file first. Migration versioning must use the `migrations` table.

## Key behaviours

- `SessionService.start(projectName:)` — find or create project, insert session with `end_time = NULL`
- `SessionService.stop(projectName:)` — set `end_time = datetime('now')` on the running session
- `SessionService.stopAll()` — stop all sessions where `end_time IS NULL`
- `SessionService.getRunning()` — return all sessions where `end_time IS NULL`
- `ReportService` — all time calculations happen here, returns structured data, never formatted strings
