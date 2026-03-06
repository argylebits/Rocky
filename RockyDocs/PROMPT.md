# Rocky — Claude Code Handoff

I have fully designed a CLI time tracking tool called **Rocky** (named after the alien character from Project Hail Mary). The design has been mapped out in detail including commands, output format, database schema, and project structure.

All design documentation is in this directory. Read ALL files before writing any code:

- `OVERVIEW.md` — project summary, goals, tech stack
- `SCHEMA.md` — SQLite database schema
- `COMMANDS.md` — all CLI commands and flags
- `OUTPUT.md` — exact output format for every command/flag combination
- `STRUCTURE.md` — repo and file structure
- `DECISIONS.md` — key design decisions already made, do not revisit these

## Your job

Scaffold and implement the Rocky CLI tool based on these docs. Start with:

1. `RockyCore` package — database connection, migrations, models, queries
2. `RockyCLI` package — ArgumentParser commands wired to RockyCore
3. Get `rocky start <project>`, `rocky stop`, and `rocky status` working end to end

## Ground rules

- Do not deviate from the design in these docs without flagging it first
- Follow the repo structure in `STRUCTURE.md` exactly
- The database schema in `SCHEMA.md` is final — implement it as specified
- Output formatting must match `OUTPUT.md` exactly
- All design decisions in `DECISIONS.md` are final
