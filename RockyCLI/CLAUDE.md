# RockyCLI — Claude Code Instructions

## Purpose

RockyCLI is the CLI binary. It handles argument parsing, calls RockyCore services, and formats output for the terminal. It contains zero business logic — all logic lives in RockyCore.

## Rules

- **No business logic** — RockyCLI only calls RockyCore and formats results
- **No direct database access** — never import sqlite-nio or touch the database directly
- **Output must match `OUTPUT.md` exactly** — column alignment, divider characters, duration format, everything
- **Use `▶` (U+25B6) for active timers** — two spaces `  ` for inactive rows
- **Use `─` (U+2500) for divider lines** — not `-` (hyphen)
- **Duration format is `Xh Ym`** — e.g. `2h 30m`, `0h 45m`, `1h 00m`. Year view uses hours only
- **24h time format** — `HH:MM`, local timezone
- **Never exit with code 0 on error** — use `exit(1)` or throw for all error conditions

## Package structure

```
RockyCLI/
├── Package.swift
└── Sources/
    └── RockyCLI/
        ├── Rocky.swift                 ← @main, ParsableCommand root
        ├── Commands/
        │   ├── Start.swift             ← rocky start <project>
        │   ├── Stop.swift              ← rocky stop [project] [--all]
        │   ├── Status.swift            ← rocky status [flags]
        │   ├── Config.swift            ← rocky config get/set/list
        │   └── Projects.swift          ← rocky projects
        └── Output/
            ├── Table.swift             ← renders table structs to terminal string
            └── Formatter.swift         ← formatDuration(), formatTime(), formatDate()
```

## Dependencies

```swift
// Package.swift
.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
.package(path: "../RockyCore")
```

## Commands reference

See `../RockyDocs/COMMANDS.md` for all commands and flags. Do not add, remove, or rename any commands or flags.

## Output reference

See `../RockyDocs/OUTPUT.md` for exact output format for every command and flag combination. Implement Table.swift to produce output that matches these examples character-for-character in terms of alignment and formatting.

## Error messages

Be clear and actionable:

```
# Unknown project
No project found with name "foo". 
Did you mean: foobar?

# No running timers
No timers currently running.

# Timer already running for same project
Timer already running for acme-corp (2h 30m).

# Project name conflict
A project named "acme-corp" already exists.
```

## Interactive stop prompt

When `rocky stop` is called with multiple timers running, read from stdin:

```
Multiple timers running:

    Project           Duration
────────────────────────────────
  1. acme-corp        2h 30m
  2. side-project     0h 45m
────────────────────────────────

Stop which? (1/2/all): 
```

Accept `1`, `2`, ... or `all`. Re-prompt on invalid input.
