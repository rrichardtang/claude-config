# claude-config

Personal Claude Code global config, synced into `~/.claude/` at the start of every session in
any project wired up to pull from this repo.

## What's in here

- `skills/caveman/SKILL.md` — the [`caveman`](https://github.com/JuliusBrussee/caveman) skill,
  vendored verbatim (MIT-licensed). Ultra-compressed output mode, off by default, turned on with
  `/caveman` or a phrase like "caveman mode".
- `skills/thermo-nuclear-code-quality-review/SKILL.md` — vendored verbatim (MIT-licensed) from
  [`cursor/plugins`](https://github.com/cursor/plugins). An unusually strict maintainability
  review (abstraction quality, file size, spaghetti growth). Explicit-invoke only; `bob-the-builder`
  runs it on its own diff before stopping (see `agents/bob-the-builder.md`, "Finishing").
- `skills/{wayfinder,grill-with-docs,grilling,domain-modeling,research,prototype}/` — vendored
  verbatim (MIT-licensed) from [`mattpocock/skills`](https://github.com/mattpocock/skills).
  Planning skills for the main session — see `CLAUDE.md`'s "Planning skills" section for which are
  explicit-invoke-only front doors (`wayfinder`, `grill-with-docs`) versus standalone building
  blocks that can auto-trigger on their own (the other four).
- `agents/bob-the-builder.md` — a generic coding subagent. Implements against an approved plan,
  runs tests, runs a `thermo-nuclear-code-quality-review` self-check, does not otherwise review
  its own work or push.
- `agents/felix-the-fixer.md` — a generic code-review subagent. Reviews a diff for correctness
  bugs and behavior-preserving simplifications; never edits.
- `CLAUDE.md` — synced to `~/.claude/CLAUDE.md`. Documents the opt-in
  `bob-the-builder` ↔ `felix-the-fixer` loop protocol (3-round cap, root-cause-vs-patch check,
  notes-ownership boundary), the planning skills, and that caveman is available but off by
  default for the main session.
- `install.sh` — does the actual sync. Safe to re-run: `skills/` and `agents/` are copied
  wholesale (this repo owns that namespace outright — every directory under `skills/` syncs, not
  just caveman), `~/.claude/CLAUDE.md` is merged via a marked block so any unrelated content
  already there survives.

## How the sync works

Nothing here installs itself. Each project that wants this config carries a `SessionStart` hook
(in that project's `.claude/settings.json`) that clones-or-pulls this repo and runs
`install.sh` at the start of every session, before the agent starts working. That's what makes
"global" actually durable in an ephemeral container — the repo is the source of truth, and every
session re-materializes `~/.claude/` from it.

## Adding this to a new project

Add a `SessionStart` hook to the project's `.claude/settings.json` that clones (or pulls, if
already cloned to a stable cache path) `rrichardtang/claude-config` and runs its `install.sh`.
See `rrichardtang/guideme`'s `.claude/settings.json` for a working example, or use Claude Code's
`session-start-hook` skill to wire up a new one.

## Editing

Change the source files here and push — every session in every wired-up project picks up the
change the next time it starts (nothing to manually re-sync). `bob-the-builder` and
`felix-the-fixer` are meant to be repo-agnostic: they never assume a `PROJECT_NOTES/`-style
convention exists, and if a project has one, they work from context handed to them rather than
reading it directly (see the loop protocol in `CLAUDE.md`).
