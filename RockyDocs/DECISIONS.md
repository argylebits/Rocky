# Rocky — Design Decisions

These decisions are final. Do not revisit or second-guess them.

---

## Concurrent timers are supported

Multiple projects can have timers running simultaneously. This is intentional — a user may be in a client meeting while also tracking time on a personal project. `rocky stop` with no args prompts which timer to stop when multiple are running.

## Project names as identifiers

Projects are identified by name (not ID) in CLI commands. Names are case-insensitive for matching but stored as first provided. Auto-create project on first `rocky start <name>` — no separate `rocky add` command.

## No "active/inactive" project state

There is no explicit active/inactive flag on projects. Recency is derived from the most recent session's `end_time`. This drives color fading in the output (when color is implemented). No manual project archiving in v1.

## Subprojects schema ready but not implemented in v1

`projects.parent_id` is in the schema to support future subprojects, but no CLI commands for managing the hierarchy in v1. Sessions always attach to leaf projects.

## sqlite-nio over GRDB or Fluent

The developer has prior experience with postgres-nio (same Vapor family). Raw SQL is preferred over ORM. sqlite-nio allows raw SQL with async/await patterns consistent with postgres-nio experience.

## `--verbose` flag for session drill-down

`--verbose` (or `-v`) switches from summary totals to individual session rows with start/stop times. It composes with all time range flags and `--project`.

## `--project` flag for filtering

`--project <name>` filters output to a single project. Composes with `--verbose` and all time range flags. When used with non-verbose mode, shows a simplified single-row table with a project header.

## Duration format

Always `Xh Ym` (e.g. `2h 30m`, `0h 45m`). Exception: year view uses hours-only (`30h`). Never show seconds.

## 24h time format

All times displayed in 24h format (`HH:MM`). All stored as UTC, displayed in local timezone.

## `running` in stop column

For active sessions in verbose view, the Stop column shows `running` (lowercase) instead of a time. The `▶` indicator also appears on that row.

## Config stored as JSON

`~/.rocky/config.json` — simple key/value. No database table for config.

## Week definition

Monday–Sunday. `--week` always shows the current Mon–Sun week.

## auto-stop config default

`auto-stop` defaults to `true` — if starting a timer on a project that already has a running timer, it errors. This setting controls behaviour when starting a new project while others are running — currently concurrent is always allowed, so `auto-stop` in v1 only prevents double-starting the same project.

## Table divider character

Use `─` (U+2500 BOX DRAWINGS LIGHT HORIZONTAL) for divider lines, not `-` (hyphen).

## ▶ indicator

Use `▶` (U+25B6 BLACK RIGHT-POINTING TRIANGLE) for active timer rows. Two spaces `  ` for inactive rows to maintain alignment.

## Color (deferred)

Color coding based on project recency is designed but NOT implemented in v1. The decay concept: green for actively running, white for recently worked on, grey for older, dark grey for very old. Implement output in monochrome first, add color as a follow-up.
