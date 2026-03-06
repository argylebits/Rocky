# Rocky — Claude Code Instructions

## Project overview

Rocky is a CLI time tracking tool built in Swift. Read the `RockyDocs/` directory for full design documentation before making any changes.

## Ground rules

- **Do not deviate from the design docs** in `RockyDocs/` without explicitly flagging it and getting confirmation
- **Do not redesign decided features** — all decisions in `RockyDocs/DECISIONS.md` are final
- **Do not add dependencies** beyond what is listed in `RockyDocs/OVERVIEW.md` without asking first
- **Do not rename commands, flags, or output fields** — these are locked in `RockyDocs/COMMANDS.md` and `RockyDocs/OUTPUT.md`
- **Do not change the database schema** without flagging it — schema is locked in `RockyDocs/SCHEMA.md`

## Repo structure

```
Rocky/
├── CLAUDE.md               ← you are here
├── RockyCore/              ← shared logic Swift package
├── RockyCLI/               ← CLI binary Swift package
├── Rocky/                  ← native app stub (do not touch)
└── RockyDocs/             ← design documentation (read only)
```

Each package has its own `CLAUDE.md` with package-specific rules.

## What to work on

- `RockyCore` and `RockyCLI` are the active packages
- `Rocky` is a stub — do not add any implementation to it
- All new features go through `RockyCore` first, then surfaced in `RockyCLI`

## GitHub workflow

Follow this workflow for every piece of work:

1. **Create an issue first** — before writing any code, create a GitHub issue describing what you're about to implement. Reference the relevant doc file (e.g. "Implements `rocky start` per `RockyDocs/COMMANDS.md`").
2. **Work in a branch** — create a branch named after the issue, e.g. `feature/1-rocky-start` or `feature/2-database-setup`.
3. **Keep PRs small and focused** — one feature or component per PR. Do not bundle unrelated changes.
4. **Open a PR referencing the issue** — PR description should reference the issue number (e.g. `Closes #1`) and summarize what was implemented.
5. **Never push directly to main** — all changes go through a PR.

### Suggested issue breakdown

Create issues in this order before starting implementation:

- `[Core] Database setup and migrations` — Database.swift, Migrations.swift, schema
- `[Core] Project model and service` — Project.swift, ProjectService.swift
- `[Core] Session model and service` — Session.swift, SessionService.swift
- `[Core] Report service` — ReportService.swift, time grouping logic
- `[CLI] rocky start` — Start.swift
- `[CLI] rocky stop` — Stop.swift, interactive prompt
- `[CLI] rocky status (no flags)` — Status.swift base
- `[CLI] rocky status time range flags` — --today, --week, --month, --year, --from/--to
- `[CLI] rocky status --verbose` — session drill-down
- `[CLI] Output formatting` — Table.swift, Formatter.swift
- `[CLI] rocky config` — Config.swift
- `[CLI] rocky projects` — Projects.swift

## When in doubt

Read `RockyDocs/DECISIONS.md` first. If the answer isn't there, ask before implementing.
