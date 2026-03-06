# Rocky — Project Overview

## What is Rocky?

Rocky is a CLI time tracking tool for a freelancer who works across multiple client projects and personal side projects. Named after the alien character from *Project Hail Mary* who communicates through numbers and music.

## Goals

- Track time across multiple client/personal projects
- Support concurrent timers (multiple projects running simultaneously)
- Provide flexible reporting with time-sliced table views
- Stay fast, local, and simple — no internet, no accounts, no setup
- Lay the foundation for a future native macOS/Linux/Windows app

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift |
| CLI framework | swift-argument-parser |
| Database | SQLite via sqlite-nio (Vapor project, standalone) |
| Shared logic | RockyCore Swift package |
| CLI binary | RockyCLI Swift package |
| Future native app | Rocky (SwiftCrossUI — stub for now) |

## Why sqlite-nio?

The developer has prior experience with postgres-nio (same Vapor family). sqlite-nio uses the same patterns and allows raw SQL queries, which is preferred over an ORM.

## Invocation

The CLI tool is invoked as `rocky`:

```bash
rocky start acme-corp
rocky stop
rocky status --week
```

## Monorepo structure

Three sibling packages at the repo root — see `STRUCTURE.md` for details.
