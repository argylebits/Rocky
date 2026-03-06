# Rocky — Repository Structure

## Top-level layout

```
Rocky/                          ← git repo root
├── RockyCore/                  ← Swift package: shared business logic
├── RockyCLI/                   ← Swift package: CLI binary
├── Rocky/                      ← Native app (SwiftCrossUI) — STUB ONLY for now
└── RockyDocs/                  ← design documentation (read only)
```

Each of `RockyCore`, `RockyCLI`, `Rocky` (the app) is its own independent Swift package with its own `Package.swift`. `RockyCLI` and `Rocky` both depend on `RockyCore` as a local package dependency.

---

## RockyCore

```
RockyCore/
├── Package.swift
└── Sources/
    └── RockyCore/
        ├── Database/
        │   ├── Database.swift          ← SQLiteConnection setup, db path, migrations runner
        │   └── Migrations.swift        ← Migration definitions (v1 creates tables)
        ├── Models/
        │   ├── Project.swift           ← Project struct
        │   └── Session.swift           ← Session struct
        └── Services/
            ├── ProjectService.swift    ← CRUD for projects
            ├── SessionService.swift    ← start/stop/query sessions
            └── ReportService.swift     ← time calculations, grouping for status views
```

### RockyCore/Package.swift dependencies

```swift
dependencies: [
    .package(url: "https://github.com/vapor/sqlite-nio.git", from: "1.0.0"),
]
```

---

## RockyCLI

```
RockyCLI/
├── Package.swift
└── Sources/
    └── RockyCLI/
        ├── Rocky.swift                 ← @main entry point, root command
        ├── Commands/
        │   ├── Start.swift             ← rocky start <project>
        │   ├── Stop.swift              ← rocky stop [project] [--all]
        │   ├── Status.swift            ← rocky status [flags]
        │   ├── Config.swift            ← rocky config get/set/list
        │   └── Projects.swift          ← rocky projects
        └── Output/
            ├── Table.swift             ← table rendering, column padding, dividers
            └── Formatter.swift         ← duration formatting, date formatting
```

### RockyCLI/Package.swift dependencies

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    .package(path: "../RockyCore"),
]
```

---

## Rocky (native app — stub only)

```
Rocky/                          ← this is the app package, not the repo root
├── Package.swift
└── Sources/
    └── Rocky/
        └── Rocky.swift              ← empty stub, just compiles
```

### Rocky/Package.swift dependencies

```swift
dependencies: [
    .package(path: "../RockyCore"),
    // SwiftCrossUI to be added when native app development begins
]
```

---

## Data files (runtime, not in repo)

```
~/.rocky/
├── rocky.db        ← SQLite database
└── config.json     ← user config/preferences
```

Create `~/.rocky/` directory on first run if it doesn't exist.
